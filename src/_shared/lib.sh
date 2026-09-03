#!/usr/bin/env bash

cargo_actions_die() {
  printf 'cargo-actions: %s\n' "$*" >&2
  exit 2
}

is_true() {
  [[ "${1:-false}" == "true" ]]
}

require_bool() {
  local name="$1"
  local value="$2"
  case "$value" in
    true|false) ;;
    *) cargo_actions_die "${name} must be true or false (got: ${value})" ;;
  esac
}

require_enum() {
  local name="$1"
  local value="$2"
  shift 2

  local candidate
  for candidate in "$@"; do
    [[ "$value" == "$candidate" ]] && return 0
  done

  cargo_actions_die "${name} must be one of: $* (got: ${value})"
}

require_enum_if_set() {
  local name="$1"
  local value="$2"
  shift 2
  [[ -z "$value" ]] && return 0
  require_enum "$name" "$value" "$@"
}

require_uint() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || cargo_actions_die "${name} must be a non-negative integer (got: ${value})"
}

require_uint_if_set() {
  local name="$1"
  local value="$2"
  [[ -z "$value" ]] && return 0
  require_uint "$name" "$value"
}

require_uint_range() {
  local name="$1"
  local value="$2"
  local min="$3"
  local max="$4"
  require_uint "$name" "$value"
  (( value >= min && value <= max )) || cargo_actions_die "${name} must be between ${min} and ${max} (got: ${value})"
}

append_lines() {
  local flag="$1"
  local values="${2:-}"
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    args+=("$flag" "$line")
  done <<< "$values"
}

append_raw_lines() {
  local values="${1:-}"
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    args+=("$line")
  done <<< "$values"
}

validate_common_inputs() {
  require_bool workspace "${CARGO_ACTION_WORKSPACE:-false}"
  require_bool all-features "${CARGO_ACTION_ALL_FEATURES:-false}"
  require_bool no-default-features "${CARGO_ACTION_NO_DEFAULT_FEATURES:-false}"
  require_bool lib "${CARGO_ACTION_LIB:-false}"
  require_bool bins "${CARGO_ACTION_BINS:-false}"
  require_bool examples "${CARGO_ACTION_EXAMPLES:-false}"
  require_bool tests "${CARGO_ACTION_TESTS:-false}"
  require_bool benches "${CARGO_ACTION_BENCHES:-false}"
  require_bool all-targets "${CARGO_ACTION_ALL_TARGETS:-false}"
  require_bool keep-going "${CARGO_ACTION_KEEP_GOING:-false}"
  require_bool release "${CARGO_ACTION_RELEASE:-false}"
  require_bool locked "${CARGO_ACTION_LOCKED:-true}"
  require_bool frozen "${CARGO_ACTION_FROZEN:-false}"
  require_bool offline "${CARGO_ACTION_OFFLINE:-false}"
  require_bool ignore-rust-version "${CARGO_ACTION_IGNORE_RUST_VERSION:-false}"
  require_bool verbose "${CARGO_ACTION_VERBOSE:-false}"
  require_bool quiet "${CARGO_ACTION_QUIET:-false}"
  require_bool future-incompat-report "${CARGO_ACTION_FUTURE_INCOMPAT_REPORT:-false}"
  require_bool no-run "${CARGO_ACTION_NO_RUN:-false}"
  require_bool no-fail-fast "${CARGO_ACTION_NO_FAIL_FAST:-false}"
  require_bool no-deps "${CARGO_ACTION_NO_DEPS:-false}"
  require_bool document-private-items "${CARGO_ACTION_DOCUMENT_PRIVATE_ITEMS:-false}"
  require_bool deny-warnings "${CARGO_ACTION_DENY_WARNINGS:-false}"
  require_bool check "${CARGO_ACTION_CHECK:-true}"
  require_bool cache "${CARGO_ACTION_CACHE:-true}"

  require_enum color "${CARGO_ACTION_COLOR:-always}" auto always never

  if is_true "${CARGO_ACTION_RELEASE:-false}" && [[ -n "${CARGO_ACTION_PROFILE:-}" ]]; then
    cargo_actions_die "release=true and profile=${CARGO_ACTION_PROFILE} are mutually exclusive"
  fi

  if is_true "${CARGO_ACTION_VERBOSE:-false}" && is_true "${CARGO_ACTION_QUIET:-false}"; then
    cargo_actions_die "verbose=true and quiet=true are mutually exclusive"
  fi
}

validate_artifact_inputs() {
  require_bool artifact "${CARGO_ACTION_ARTIFACT:-false}"
  require_bool artifact-overwrite "${CARGO_ACTION_ARTIFACT_OVERWRITE:-false}"
  require_bool artifact-include-hidden-files "${CARGO_ACTION_ARTIFACT_INCLUDE_HIDDEN_FILES:-false}"
  require_bool artifact-archive "${CARGO_ACTION_ARTIFACT_ARCHIVE:-true}"
  require_enum artifact-if-no-files-found "${CARGO_ACTION_ARTIFACT_IF_NO_FILES_FOUND:-error}" error warn ignore
  require_uint artifact-retention-days "${CARGO_ACTION_ARTIFACT_RETENTION_DAYS:-7}"
  require_uint_range artifact-compression-level "${CARGO_ACTION_ARTIFACT_COMPRESSION_LEVEL:-6}" 0 9
}
