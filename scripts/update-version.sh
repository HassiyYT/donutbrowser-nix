#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly GITHUB_REPO="zhom/donutbrowser"
readonly GITHUB_API_BASE="https://api.github.com/repos/${GITHUB_REPO}/releases"
readonly APPIMAGE_ARCH_REGEX='(amd64|x86_64|x64)'

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
  command -v awk >/dev/null 2>&1 || { log_error "awk is required but not installed."; exit 1; }
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
  --version VERSION   Pin to a specific release version (e.g. 0.13.9)
  --help              Show this help message

Examples:
  $0
  $0 --check
  $0 --version 0.13.9
USAGE
}

get_current_version() {
  sed -n 's/.*version = "\([^"]*\)".*/\1/p' package.nix | head -1
}

get_current_asset_name() {
  sed -n 's/.*assetName = "\([^"]*\)".*/\1/p' package.nix | head -1
}

get_current_hash() {
  sed -n 's/.*hash = "\([^"]*\)".*/\1/p' package.nix | head -1
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

extract_linux_appimage_asset_name() {
  jq -r --arg archRegex "$APPIMAGE_ARCH_REGEX" '
    [ .assets[] | select(.name | test("\\.AppImage$"; "i")) ] as $assets
    | if ($assets | length) == 0 then
        ""
      else
        (($assets | map(select(.name | test($archRegex; "i"))) | first) // ($assets | first)).name
      end
  '
}

extract_linux_appimage_asset_url() {
  jq -r --arg archRegex "$APPIMAGE_ARCH_REGEX" '
    [ .assets[] | select(.name | test("\\.AppImage$"; "i")) ] as $assets
    | if ($assets | length) == 0 then
        ""
      else
        (($assets | map(select(.name | test($archRegex; "i"))) | first) // ($assets | first)).browser_download_url
      end
  '
}

prefetch_sri_hash() {
  local url="$1"
  local nix_hash

  nix_hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null | tail -1)
  nix hash to-sri --type sha256 "$nix_hash" | tr -d '\n'
}

update_package_file() {
  local new_version="$1"
  local new_asset_name="$2"
  local new_hash="$3"
  local tmp_file

  tmp_file=$(mktemp)

  awk \
    -v new_version="$new_version" \
    -v new_asset_name="$new_asset_name" \
    -v new_hash="$new_hash" '
      !version_updated && $0 ~ /^[[:space:]]*version = "/ {
        sub(/"[^"]+"/, "\"" new_version "\"")
        version_updated = 1
      }

      !asset_updated && $0 ~ /^[[:space:]]*assetName = "/ {
        sub(/"[^"]+"/, "\"" new_asset_name "\"")
        asset_updated = 1
      }

      !hash_updated && $0 ~ /^[[:space:]]*hash = "sha256-/ {
        sub(/"sha256-[^"]+"/, "\"" new_hash "\"")
        hash_updated = 1
      }

      { print }
    ' package.nix > "$tmp_file"

  mv "$tmp_file" package.nix
}

print_state() {
  local current_version="$1"
  local latest_version="$2"
  local current_asset="$3"
  local latest_asset="$4"
  local current_hash="$5"
  local latest_hash="$6"
  local update_needed="$7"

  echo "current_version=${current_version}"
  echo "latest_version=${latest_version}"
  echo "current_asset=${current_asset}"
  echo "latest_asset=${latest_asset}"
  echo "current_hash=${current_hash}"
  echo "latest_hash=${latest_hash}"
  echo "update_needed=${update_needed}"
}

main() {
  ensure_in_repository_root
  local check_only
  check_only=false
  local target_version
  target_version=""

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

  ensure_required_tools_installed

  local current_version
  current_version=$(get_current_version)

  local current_asset
  current_asset=$(get_current_asset_name)

  local current_hash
  current_hash=$(get_current_hash)

  if [ -z "$current_version" ] || [ -z "$current_asset" ] || [ -z "$current_hash" ]; then
    log_error "Failed to parse current package.nix values"
    exit 1
  fi

  log_info "Fetching release metadata for ${GITHUB_REPO}..."
  local release_json
  release_json=$(fetch_release_json "$target_version")

  local latest_version
  latest_version=$(echo "$release_json" | extract_version_from_release_json)

  local latest_asset
  latest_asset=$(echo "$release_json" | extract_linux_appimage_asset_name)

  local latest_asset_url
  latest_asset_url=$(echo "$release_json" | extract_linux_appimage_asset_url)

  if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
    log_error "Could not determine latest release version"
    exit 1
  fi

  if [ -z "$latest_asset" ] || [ "$latest_asset" = "null" ] || [ -z "$latest_asset_url" ] || [ "$latest_asset_url" = "null" ]; then
    log_error "Could not find a Linux AppImage asset in the selected release"
    exit 1
  fi

  log_info "Prefetching hash for ${latest_asset}..."
  local latest_hash
  latest_hash=$(prefetch_sri_hash "$latest_asset_url")

  if [ -z "$latest_hash" ]; then
    log_error "Failed to prefetch AppImage hash"
    exit 1
  fi

  local update_needed=false
  if [ "$current_version" != "$latest_version" ] || [ "$current_asset" != "$latest_asset" ] || [ "$current_hash" != "$latest_hash" ]; then
    update_needed=true
  fi

  print_state "$current_version" "$latest_version" "$current_asset" "$latest_asset" "$current_hash" "$latest_hash" "$update_needed"

  if [ "$check_only" = "true" ]; then
    if [ "$update_needed" = "true" ]; then
      log_info "Update required"
      exit 1
    else
      log_info "Already up to date"
      exit 0
    fi
  fi

  if [ "$update_needed" != "true" ]; then
    log_info "Already up to date"
    exit 0
  fi

  local backup_file
  backup_file=$(mktemp)
  cp package.nix "$backup_file"

  log_info "Updating package.nix..."
  update_package_file "$latest_version" "$latest_asset" "$latest_hash"

  log_info "Verifying build..."
  if ! nix build .#donutbrowser > /dev/null 2>&1; then
    log_error "Build verification failed. Restoring package.nix"
    cp "$backup_file" package.nix
    rm -f "$backup_file"
    exit 1
  fi

  rm -f "$backup_file"

  log_info "Successfully updated donutbrowser from ${current_version} to ${latest_version}"
  git diff --stat package.nix || true
}

main "$@"
