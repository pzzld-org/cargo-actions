#!/usr/bin/env bash
set -euo pipefail

SHARED_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SHARED_DIR
# shellcheck source=lib.sh
source "${SHARED_DIR}/lib.sh"

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set by GitHub Actions}"

working_directory="${CARGO_ACTION_WORKING_DIRECTORY-.}"
artifact_path="${CARGO_ACTION_ARTIFACT_PATH:-}"
target_dir="${CARGO_ACTION_TARGET_DIR:-}"

[[ -n "$working_directory" ]] || cargo_actions_die "working-directory must not be empty"

resolve_from_working_directory() {
  local value="$1"

  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    cargo_actions_die "artifact paths must not contain newlines"
  fi

  case "$value" in
    /*|[A-Za-z]:[\\/]*|\\\\*)
      printf '%s' "$value"
      ;;
    *)
      if [[ "$working_directory" == "." ]]; then
        printf '%s' "$value"
      else
        printf '%s/%s' "${working_directory%/}" "$value"
      fi
      ;;
  esac
}

if [[ -n "$artifact_path" ]]; then
  resolved="$(resolve_from_working_directory "$artifact_path")"
elif [[ -n "$target_dir" ]]; then
  resolved="$(resolve_from_working_directory "$target_dir")"
else
  resolved="$(resolve_from_working_directory target)"
fi

printf 'path=%s\n' "$resolved" >> "$GITHUB_OUTPUT"
printf 'cargo-actions: artifact path: %s\n' "$resolved"
