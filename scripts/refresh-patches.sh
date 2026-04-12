#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'
readonly DEFAULT_SOURCE_REPO='/home/h/dev/donutbrowser'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

ensure_in_repository_root() {
  if [ ! -f "flake.nix" ] || [ ! -f "package.nix" ]; then
    log_error "flake.nix or package.nix not found. Run this script from the repository root."
    exit 1
  fi
}

ensure_required_tools_installed() {
  command -v git >/dev/null 2>&1 || { log_error "git is required but not installed."; exit 1; }
}

print_usage() {
  cat <<USAGE
Usage: $0 [OPTIONS]

Options:
  --version VERSION     Refresh patches against a specific upstream release (without leading v)
  --source-repo PATH    Source checkout to use for temporary worktrees (default: ${DEFAULT_SOURCE_REPO})
  --help                Show this help message
USAGE
}

get_packaging_patch_paths() {
  awk '
    /^[[:space:]]*patches = \[/ { in_patches = 1; next }
    in_patches && /^[[:space:]]*\];/ { in_patches = 0; next }
    in_patches {
      line = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      gsub(/,/, "", line)
      if (line ~ /^\.\/patches\/.*\.patch$/) {
        sub(/^\.\//, "", line)
        print line
      }
    }
  ' package.nix
}

resolve_target_version() {
  local source_repo="$1"
  local requested_version="$2"

  if [ -n "$requested_version" ]; then
    printf '%s\n' "${requested_version#v}"
    return 0
  fi

  local latest_tag
  latest_tag=$(git -C "$source_repo" tag --list 'v*' --sort=-version:refname | head -n 1)
  if [ -z "$latest_tag" ]; then
    log_error "Could not find any release tags in $source_repo"
    exit 1
  fi

  printf '%s\n' "${latest_tag#v}"
}

create_release_worktree() {
  local source_repo="$1"
  local version="$2"
  local worktree_dir="$3"

  if ! git -C "$source_repo" rev-parse --verify --quiet "refs/tags/v${version}" >/dev/null; then
    log_error "Tag v${version} not found in $source_repo"
    exit 1
  fi

  git -C "$source_repo" worktree add --detach "$worktree_dir" "v${version}" >/dev/null
}

remove_release_worktree() {
  local source_repo="$1"
  local worktree_dir="$2"
  git -C "$source_repo" worktree remove --force "$worktree_dir" >/dev/null 2>&1 || true
}

refresh_one_patch() {
  local repo_root="$1"
  local worktree_dir="$2"
  local patch_path="$3"
  local patch_tmp

  patch_tmp=$(mktemp)
  if ! git -C "$worktree_dir" apply --3way --index "$repo_root/$patch_path" >"$patch_tmp" 2>&1; then
    cat "$patch_tmp"
    rm -f "$patch_tmp"
    return 1
  fi
  rm -f "$patch_tmp"

  local new_patch
  new_patch=$(mktemp)
  git -C "$worktree_dir" diff --cached --binary --full-index HEAD -- > "$new_patch"

  if [ ! -s "$new_patch" ]; then
    : > "$repo_root/$patch_path"
  else
    mv "$new_patch" "$repo_root/$patch_path"
  fi

  git -C "$worktree_dir" \
    -c user.name='patch-refresh-bot' \
    -c user.email='patch-refresh-bot@local.invalid' \
    commit -q -m "refresh $(basename "$patch_path")"
}

main() {
  ensure_in_repository_root
  ensure_required_tools_installed

  local source_repo="$DEFAULT_SOURCE_REPO"
  local target_version=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        target_version="${2:-}"
        if [ -z "$target_version" ]; then
          log_error "--version requires a value"
          exit 1
        fi
        shift 2
        ;;
      --source-repo)
        source_repo="${2:-}"
        if [ -z "$source_repo" ]; then
          log_error "--source-repo requires a value"
          exit 1
        fi
        shift 2
        ;;
      --help)
        print_usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        print_usage
        exit 1
        ;;
    esac
  done

  if [ ! -d "$source_repo/.git" ]; then
    log_error "Source repo '$source_repo' is not a git repository"
    exit 1
  fi

  local repo_root
  repo_root=$(pwd -P)
  target_version=$(resolve_target_version "$source_repo" "$target_version")

  local worktree_dir
  worktree_dir=$(mktemp -d)
  trap 'remove_release_worktree "$source_repo" "$worktree_dir"; rm -rf "$worktree_dir"' EXIT

  log_info "Refreshing carried patches against upstream release v${target_version} using $source_repo"
  create_release_worktree "$source_repo" "$target_version" "$worktree_dir"

  local patch_path
  local -a refreshed_patches=()
  local -a failed_patches=()

  while IFS= read -r patch_path; do
    [ -n "$patch_path" ] || continue
    log_info "Refreshing $patch_path"

    if refresh_one_patch "$repo_root" "$worktree_dir" "$patch_path"; then
      refreshed_patches+=("$patch_path")
    else
      failed_patches+=("$patch_path")
      break
    fi
  done < <(get_packaging_patch_paths)

  if [ "${#refreshed_patches[@]}" -gt 0 ]; then
    log_info "Refreshed patches: ${refreshed_patches[*]}"
  fi

  if [ "${#failed_patches[@]}" -gt 0 ]; then
    log_warn "Patch refresh stopped after failure. Remaining manual review required for: ${failed_patches[*]}"
    exit 1
  fi

  log_info "All carried patches refreshed successfully for v${target_version}"
}

main "$@"
