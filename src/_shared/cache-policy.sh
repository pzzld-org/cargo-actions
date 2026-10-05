#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_bool save-if "${CARGO_ACTION_CACHE_SAVE:-false}"
require_bool sccache "${CARGO_ACTION_SCCACHE:-true}"
[[ -n "${CARGO_ACTION_CACHE_KEY:-}" ]] || cargo_actions_die 'cache key must not be empty'

# Only a caller-selected push on the repository default branch may write.
# PRs (including same-repository PRs), tags and dispatches remain restore-only.
write=false
if [[ "${CARGO_ACTION_CACHE_SAVE:-false}" == true &&
      "${GITHUB_EVENT_NAME:-}" == push &&
      -n "${CARGO_ACTION_DEFAULT_BRANCH:-}" &&
      "${GITHUB_REF:-}" == "refs/heads/${CARGO_ACTION_DEFAULT_BRANCH}" ]]; then
  write=true
fi
compiler="${CARGO_ACTION_SCCACHE:-true}"
mode=disabled
if [[ "$compiler" == true ]]; then
  mode=READ_ONLY
  [[ "$write" == true ]] && mode=READ_WRITE
fi
printf 'write-enabled=%s\nsccache-enabled=%s\nsccache-mode=%s\n' "$write" "$compiler" "$mode" >> "${GITHUB_OUTPUT:?}"
printf 'cargo-actions: dependency cache write=%s; sccache=%s\n' "$write" "$mode"
