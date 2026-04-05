#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly GITHUB_REPO="zhom/donutbrowser"
readonly GITHUB_API_BASE="https://api.github.com/repos/${GITHUB_REPO}/releases"
readonly FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

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
  command -v curl >/dev/null 2>&1 || { log_error "curl is required but not installed."; exit 1; }
  command -v jq >/dev/null 2>&1 || { log_error "jq is required but not installed."; exit 1; }
  command -v nix >/dev/null 2>&1 || { log_error "nix is required but not installed."; exit 1; }
  command -v nix-prefetch-url >/dev/null 2>&1 || { log_error "nix-prefetch-url is required but not installed."; exit 1; }
}

print_usage() {
  cat <<USAGE
Usage: $0 [OPTIONS]

Options:
  --check             Check whether an update is needed (no file changes)
  --version VERSION   Pin to a specific release version (e.g. 0.19.0)
  --help              Show this help message
USAGE
}

get_current_version() {
  sed -n 's/^[[:space:]]*version = "\([^"]*\)";/\1/p' package.nix | head -1
}

get_current_src_hash() {
  sed -n 's/^[[:space:]]*srcHash = "\([^"]*\)";/\1/p' package.nix | head -1
}

get_current_pnpm_hash() {
  sed -n 's/^[[:space:]]*pnpmDepsHash = "\([^"]*\)";/\1/p' package.nix | head -1
}

get_current_cargo_hash() {
  sed -n 's/^[[:space:]]*cargoDepsHash = "\([^"]*\)";/\1/p' package.nix | head -1
}

github_api_get() {
  local url="$1"
  local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

  if [ -n "$token" ]; then
    curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${token}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$url"
  else
    curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$url"
  fi
}

fetch_release_json() {
  local target_version="$1"

  if [ -n "$target_version" ]; then
    github_api_get "${GITHUB_API_BASE}/tags/v${target_version}"
  else
    github_api_get "${GITHUB_API_BASE}/latest"
  fi
}

extract_version_from_release_json() {
  jq -r '.tag_name | ltrimstr("v")'
}

prefetch_sri_hash() {
  local url="$1"
  local nix_hash

  nix_hash=$(nix-prefetch-url --type sha256 --unpack "$url" 2>/dev/null | tail -1)
  nix hash to-sri --type sha256 "$nix_hash" | tr -d '\n'
}

update_package_file() {
  local new_version="$1"
  local new_src_hash="$2"
  local new_pnpm_hash="$3"
  local new_cargo_hash="$4"
  local tmp_file

  tmp_file=$(mktemp)

  awk \
    -v new_version="$new_version" \
    -v new_src_hash="$new_src_hash" \
    -v new_pnpm_hash="$new_pnpm_hash" \
    -v new_cargo_hash="$new_cargo_hash" '
      !version_updated && $0 ~ /^[[:space:]]*version = "/ {
        sub(/"[^"]+"/, "\"" new_version "\"")
        version_updated = 1
      }
      !src_hash_updated && $0 ~ /^[[:space:]]*srcHash = "/ {
        sub(/"[^"]+"/, "\"" new_src_hash "\"")
        src_hash_updated = 1
      }
      !pnpm_hash_updated && $0 ~ /^[[:space:]]*pnpmDepsHash = "/ {
        sub(/"[^"]+"/, "\"" new_pnpm_hash "\"")
        pnpm_hash_updated = 1
      }
      !cargo_hash_updated && $0 ~ /^[[:space:]]*cargoDepsHash = "/ {
        sub(/"[^"]+"/, "\"" new_cargo_hash "\"")
        cargo_hash_updated = 1
      }
      { print }
    ' package.nix > "$tmp_file"

  mv "$tmp_file" package.nix
}

resolve_fixed_output_hash() {
  local target="$1"
  local output
  local status
  local got_hash

  set +e
  output=$(nix build "$target" --no-link 2>&1)
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo ""
    return 0
  fi

  got_hash=$(printf '%s\n' "$output" | sed -n 's/^[[:space:]]*got:[[:space:]]*//p' | tail -1)
  if [ -z "$got_hash" ]; then
    printf '%s\n' "$output" >&2
    return 1
  fi

  printf '%s\n' "$got_hash"
}

print_state() {
  local current_version="$1"
  local latest_version="$2"
  local current_src_hash="$3"
  local latest_src_hash="$4"
  local current_pnpm_hash="$5"
  local latest_pnpm_hash="$6"
  local current_cargo_hash="$7"
  local latest_cargo_hash="$8"
  local update_needed="$9"

  echo "current_version=${current_version}"
  echo "latest_version=${latest_version}"
  echo "current_src_hash=${current_src_hash}"
  echo "latest_src_hash=${latest_src_hash}"
  echo "current_pnpm_hash=${current_pnpm_hash}"
  echo "latest_pnpm_hash=${latest_pnpm_hash}"
  echo "current_cargo_hash=${current_cargo_hash}"
  echo "latest_cargo_hash=${latest_cargo_hash}"
  echo "update_needed=${update_needed}"
}

main() {
  ensure_in_repository_root
  ensure_required_tools_installed

  local check_only=false
  local target_version=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)
        check_only=true
        shift
        ;;
      --version)
        target_version="${2:-}"
        if [ -z "$target_version" ]; then
          log_error "--version requires a value"
          exit 1
        fi
        target_version="${target_version#v}"
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

  local current_version
  current_version=$(get_current_version)
  local current_src_hash
  current_src_hash=$(get_current_src_hash)
  local current_pnpm_hash
  current_pnpm_hash=$(get_current_pnpm_hash)
  local current_cargo_hash
  current_cargo_hash=$(get_current_cargo_hash)

  local release_json
  release_json=$(fetch_release_json "$target_version")

  local latest_version
  latest_version=$(printf '%s\n' "$release_json" | extract_version_from_release_json)
  if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
    log_error "Could not determine latest release version"
    exit 1
  fi

  local src_url
  src_url="https://github.com/zhom/donutbrowser/archive/refs/tags/v${latest_version}.tar.gz"
  local latest_src_hash
  latest_src_hash=$(prefetch_sri_hash "$src_url")

  local update_needed=false
  if [ "$current_version" != "$latest_version" ]; then
    update_needed=true
  fi

  if [ "$check_only" = true ]; then
    print_state \
      "$current_version" \
      "$latest_version" \
      "$current_src_hash" \
      "$latest_src_hash" \
      "$current_pnpm_hash" \
      "$current_pnpm_hash" \
      "$current_cargo_hash" \
      "$current_cargo_hash" \
      "$update_needed"
    if [ "$update_needed" = true ]; then
      exit 1
    fi
    exit 0
  fi

  log_info "Updating Donut Browser to version ${latest_version}..."

  update_package_file "$latest_version" "$latest_src_hash" "$FAKE_HASH" "$FAKE_HASH"

  log_info "Resolving pnpm dependency hash..."
  local latest_pnpm_hash
  latest_pnpm_hash=$(resolve_fixed_output_hash .#pnpm-deps)
  if [ -z "$latest_pnpm_hash" ]; then
    latest_pnpm_hash=$(get_current_pnpm_hash)
  fi
  update_package_file "$latest_version" "$latest_src_hash" "$latest_pnpm_hash" "$FAKE_HASH"

  log_info "Resolving cargo dependency hash..."
  local latest_cargo_hash
  latest_cargo_hash=$(resolve_fixed_output_hash .#cargo-deps)
  if [ -z "$latest_cargo_hash" ]; then
    latest_cargo_hash=$(get_current_cargo_hash)
  fi
  update_package_file "$latest_version" "$latest_src_hash" "$latest_pnpm_hash" "$latest_cargo_hash"

  log_info "Verifying full package build..."
  nix build .#donutbrowser --no-link

  print_state \
    "$current_version" \
    "$latest_version" \
    "$current_src_hash" \
    "$latest_src_hash" \
    "$current_pnpm_hash" \
    "$latest_pnpm_hash" \
    "$current_cargo_hash" \
    "$latest_cargo_hash" \
    true
}

main "$@"
