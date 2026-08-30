#!/usr/bin/env bash
set -euo pipefail

command="${1:?cargo subcommand is required}"

is_true() {
  case "${1:-false}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
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

append_common_package_args() {
  if is_true "${CARGO_ACTION_WORKSPACE:-false}"; then
    args+=(--workspace)
  fi

  if [[ -n "${CARGO_ACTION_PACKAGE:-}" ]]; then
    args+=(--package "${CARGO_ACTION_PACKAGE}")
  fi
  append_lines --package "${CARGO_ACTION_PACKAGES:-}"

  append_lines --exclude "${CARGO_ACTION_EXCLUDE:-}"
}

append_common_target_args() {
  if is_true "${CARGO_ACTION_LIB:-false}"; then
    args+=(--lib)
  fi

  append_lines --bin "${CARGO_ACTION_BIN:-}"
  if is_true "${CARGO_ACTION_BINS:-false}"; then
    args+=(--bins)
  fi

  append_lines --example "${CARGO_ACTION_EXAMPLE:-}"
  if is_true "${CARGO_ACTION_EXAMPLES:-false}"; then
    args+=(--examples)
  fi

  append_lines --test "${CARGO_ACTION_TEST:-}"
  if is_true "${CARGO_ACTION_TESTS:-false}"; then
    args+=(--tests)
  fi

  append_lines --bench "${CARGO_ACTION_BENCH:-}"
  if is_true "${CARGO_ACTION_BENCHES:-false}"; then
    args+=(--benches)
  fi

  if is_true "${CARGO_ACTION_ALL_TARGETS:-false}"; then
    args+=(--all-targets)
  fi
}

append_common_feature_args() {
  if is_true "${CARGO_ACTION_ALL_FEATURES:-false}"; then
    args+=(--all-features)
  fi

  if is_true "${CARGO_ACTION_NO_DEFAULT_FEATURES:-false}"; then
    args+=(--no-default-features)
  fi

  case "${CARGO_ACTION_FEATURES:-}" in
    ""|default) ;;
    all)
      if ! is_true "${CARGO_ACTION_ALL_FEATURES:-false}"; then
        args+=(--all-features)
      fi
      ;;
    *)
      args+=(--features "${CARGO_ACTION_FEATURES}")
      ;;
  esac
}

append_common_compile_args() {
  if [[ -n "${CARGO_ACTION_JOBS:-}" ]]; then
    args+=(--jobs "${CARGO_ACTION_JOBS}")
  fi

  if is_true "${CARGO_ACTION_KEEP_GOING:-false}"; then
    case "$command" in
      test|bench)
        printf 'cargo-actions: keep-going is not supported by cargo %s; use no-fail-fast instead\n' "$command" >&2
        exit 2
        ;;
      *)
        args+=(--keep-going)
        ;;
    esac
  fi

  if is_true "${CARGO_ACTION_RELEASE:-false}" && [[ -n "${CARGO_ACTION_PROFILE:-}" ]]; then
    printf 'cargo-actions: release=true and profile=%s are mutually exclusive\n' "${CARGO_ACTION_PROFILE}" >&2
    exit 2
  fi

  if is_true "${CARGO_ACTION_RELEASE:-false}"; then
    args+=(--release)
  elif [[ -n "${CARGO_ACTION_PROFILE:-}" ]]; then
    args+=(--profile "${CARGO_ACTION_PROFILE}")
  fi

  if [[ -n "${CARGO_ACTION_TARGET:-}" ]]; then
    args+=(--target "${CARGO_ACTION_TARGET}")
  fi

  if [[ -n "${CARGO_ACTION_TARGET_DIR:-}" ]]; then
    args+=(--target-dir "${CARGO_ACTION_TARGET_DIR}")
  fi
}

append_common_manifest_args() {
  if [[ -n "${CARGO_ACTION_MANIFEST_PATH:-}" ]]; then
    args+=(--manifest-path "${CARGO_ACTION_MANIFEST_PATH}")
  fi

  if is_true "${CARGO_ACTION_LOCKED:-true}"; then
    args+=(--locked)
  fi

  if is_true "${CARGO_ACTION_FROZEN:-false}"; then
    args+=(--frozen)
  fi

  if is_true "${CARGO_ACTION_OFFLINE:-false}"; then
    args+=(--offline)
  fi

  if is_true "${CARGO_ACTION_IGNORE_RUST_VERSION:-false}"; then
    args+=(--ignore-rust-version)
  fi

  if is_true "${CARGO_ACTION_FUTURE_INCOMPAT_REPORT:-false}"; then
    args+=(--future-incompat-report)
  fi

  append_lines --config "${CARGO_ACTION_CONFIG:-}"
}

append_common_output_args() {
  if is_true "${CARGO_ACTION_VERBOSE:-false}" && is_true "${CARGO_ACTION_QUIET:-false}"; then
    printf 'cargo-actions: verbose=true and quiet=true are mutually exclusive\n' >&2
    exit 2
  fi

  if is_true "${CARGO_ACTION_VERBOSE:-false}"; then
    args+=(--verbose)
  fi

  if is_true "${CARGO_ACTION_QUIET:-false}"; then
    args+=(--quiet)
  fi

  if [[ -n "${CARGO_ACTION_COLOR:-always}" ]]; then
    args+=(--color "${CARGO_ACTION_COLOR:-always}")
  fi

  if [[ -n "${CARGO_ACTION_MESSAGE_FORMAT:-}" ]]; then
    args+=(--message-format "${CARGO_ACTION_MESSAGE_FORMAT}")
  fi
}

args=("$command")

if [[ "$command" == "fmt" ]]; then
  if [[ -n "${CARGO_ACTION_MANIFEST_PATH:-}" ]]; then
    args+=(--manifest-path "${CARGO_ACTION_MANIFEST_PATH}")
  fi

  if is_true "${CARGO_ACTION_WORKSPACE:-false}"; then
    args+=(--all)
  fi

  if [[ -n "${CARGO_ACTION_PACKAGE:-}" ]]; then
    args+=(--package "${CARGO_ACTION_PACKAGE}")
  fi
  append_lines --package "${CARGO_ACTION_PACKAGES:-}"

  if is_true "${CARGO_ACTION_CHECK:-true}"; then
    args+=(--check)
  fi

  if [[ -n "${CARGO_ACTION_MESSAGE_FORMAT:-}" ]]; then
    args+=(--message-format "${CARGO_ACTION_MESSAGE_FORMAT}")
  fi

  append_raw_lines "${CARGO_ACTION_EXTRA_ARGS:-}"
else
  append_common_package_args
  append_common_target_args
  append_common_feature_args
  append_common_compile_args
  append_common_manifest_args
  append_common_output_args

  case "$command" in
    test|bench)
      if is_true "${CARGO_ACTION_NO_RUN:-false}"; then
        args+=(--no-run)
      fi
      if is_true "${CARGO_ACTION_NO_FAIL_FAST:-false}"; then
        args+=(--no-fail-fast)
      fi
      ;;
    clippy|doc)
      if is_true "${CARGO_ACTION_NO_DEPS:-false}"; then
        args+=(--no-deps)
      fi
      ;;
  esac

  if [[ "$command" == "doc" ]] && is_true "${CARGO_ACTION_DOCUMENT_PRIVATE_ITEMS:-false}"; then
    args+=(--document-private-items)
  fi

  if [[ "$command" == "test" || "$command" == "bench" ]] && [[ -n "${CARGO_ACTION_FILTER:-}" ]]; then
    args+=("${CARGO_ACTION_FILTER}")
  fi

  append_raw_lines "${CARGO_ACTION_EXTRA_ARGS:-}"

  trailing=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    trailing+=("$line")
  done <<< "${CARGO_ACTION_TRAILING_ARGS:-}"

  if [[ "$command" == "clippy" ]] && is_true "${CARGO_ACTION_DENY_WARNINGS:-false}"; then
    trailing+=(-D warnings)
  fi

  if (( ${#trailing[@]} > 0 )); then
    args+=(--)
    args+=("${trailing[@]}")
  fi
fi

printf 'cargo'
printf ' %q' "${args[@]}"
printf '\n'

exec cargo "${args[@]}"
