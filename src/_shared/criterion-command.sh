#!/usr/bin/env bash
set -euo pipefail

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

args=(criterion)

if is_true "${CARGO_ACTION_WORKSPACE:-false}"; then args+=(--workspace); fi
if [[ -n "${CARGO_ACTION_PACKAGE:-}" ]]; then args+=(--package "${CARGO_ACTION_PACKAGE}"); fi
append_lines --package "${CARGO_ACTION_PACKAGES:-}"
append_lines --exclude "${CARGO_ACTION_EXCLUDE:-}"

if is_true "${CARGO_ACTION_LIB:-false}"; then args+=(--lib); fi
append_lines --bin "${CARGO_ACTION_BIN:-}"
if is_true "${CARGO_ACTION_BINS:-false}"; then args+=(--bins); fi
append_lines --example "${CARGO_ACTION_EXAMPLE:-}"
if is_true "${CARGO_ACTION_EXAMPLES:-false}"; then args+=(--examples); fi
append_lines --test "${CARGO_ACTION_TEST:-}"
if is_true "${CARGO_ACTION_TESTS:-false}"; then args+=(--tests); fi
append_lines --bench "${CARGO_ACTION_BENCH:-}"
if is_true "${CARGO_ACTION_BENCHES:-false}"; then args+=(--benches); fi
if is_true "${CARGO_ACTION_ALL_TARGETS:-false}"; then args+=(--all-targets); fi

if is_true "${CARGO_ACTION_ALL_FEATURES:-false}"; then
  args+=(--all-features)
fi
if is_true "${CARGO_ACTION_NO_DEFAULT_FEATURES:-false}"; then
  args+=(--no-default-features)
fi
case "${CARGO_ACTION_FEATURES:-}" in
  ""|default) ;;
  all)
    if ! is_true "${CARGO_ACTION_ALL_FEATURES:-false}"; then args+=(--all-features); fi
    ;;
  *) args+=(--features "${CARGO_ACTION_FEATURES}") ;;
esac

if [[ -n "${CARGO_ACTION_JOBS:-}" ]]; then args+=(--jobs "${CARGO_ACTION_JOBS}"); fi
if [[ -n "${CARGO_ACTION_PROFILE:-}" ]]; then
  printf 'cargo-actions: profile=%s is not supported by cargo-criterion; use runner=cargo for custom Cargo profiles\n' "${CARGO_ACTION_PROFILE}" >&2
  exit 2
fi
# cargo-criterion uses the bench profile by default, so release=true is already its normal behavior.
if [[ -n "${CARGO_ACTION_TARGET:-}" ]]; then args+=(--target "${CARGO_ACTION_TARGET}"); fi
if [[ -n "${CARGO_ACTION_TARGET_DIR:-}" ]]; then args+=(--target-dir "${CARGO_ACTION_TARGET_DIR}"); fi
if [[ -n "${CARGO_ACTION_MANIFEST_PATH:-}" ]]; then args+=(--manifest-path "${CARGO_ACTION_MANIFEST_PATH}"); fi

if is_true "${CARGO_ACTION_LOCKED:-true}"; then args+=(--locked); fi
if is_true "${CARGO_ACTION_FROZEN:-false}"; then args+=(--frozen); fi
if is_true "${CARGO_ACTION_OFFLINE:-false}"; then args+=(--offline); fi
if is_true "${CARGO_ACTION_IGNORE_RUST_VERSION:-false}"; then
  printf 'cargo-actions: ignore-rust-version is not supported by cargo-criterion\n' >&2
  exit 2
fi
if is_true "${CARGO_ACTION_FUTURE_INCOMPAT_REPORT:-false}"; then
  printf 'cargo-actions: future-incompat-report is not supported by cargo-criterion\n' >&2
  exit 2
fi
if [[ -n "${CARGO_ACTION_CONFIG:-}" ]]; then
  printf 'cargo-actions: config overrides are not supported by cargo-criterion; use runner=cargo when --config is required\n' >&2
  exit 2
fi
if is_true "${CARGO_ACTION_QUIET:-false}"; then
  printf 'cargo-actions: quiet=true is not a Cargo build flag for cargo-criterion; use criterion-output-format=quiet\n' >&2
  exit 2
fi
if is_true "${CARGO_ACTION_VERBOSE:-false}"; then args+=(--verbose); fi
if [[ -n "${CARGO_ACTION_COLOR:-always}" ]]; then args+=(--color "${CARGO_ACTION_COLOR:-always}"); fi
if [[ -n "${CARGO_ACTION_MESSAGE_FORMAT:-}" ]]; then
  printf 'cargo-actions: message-format is Cargo output syntax and is not supported by cargo-criterion; use criterion-message-format\n' >&2
  exit 2
fi

if is_true "${CARGO_ACTION_NO_RUN:-false}"; then args+=(--no-run); fi
if is_true "${CARGO_ACTION_NO_FAIL_FAST:-false}"; then args+=(--no-fail-fast); fi
if is_true "${CRITERION_ACTION_DEBUG:-false}"; then args+=(--debug); fi
if [[ -n "${CRITERION_ACTION_MANIFEST_PATH:-}" ]]; then args+=(--criterion-manifest-path "${CRITERION_ACTION_MANIFEST_PATH}"); fi
if [[ -n "${CRITERION_ACTION_OUTPUT_FORMAT:-criterion}" ]]; then args+=(--output-format "${CRITERION_ACTION_OUTPUT_FORMAT:-criterion}"); fi
if [[ -n "${CRITERION_ACTION_PLOTTING_BACKEND:-}" ]]; then args+=(--plotting-backend "${CRITERION_ACTION_PLOTTING_BACKEND}"); fi
if [[ -n "${CRITERION_ACTION_MESSAGE_FORMAT:-}" ]]; then args+=(--message-format "${CRITERION_ACTION_MESSAGE_FORMAT}"); fi
if [[ -n "${CRITERION_ACTION_HISTORY_ID:-}" ]]; then args+=(--history-id "${CRITERION_ACTION_HISTORY_ID}"); fi
if [[ -n "${CRITERION_ACTION_HISTORY_DESCRIPTION:-}" ]]; then args+=(--history-description "${CRITERION_ACTION_HISTORY_DESCRIPTION}"); fi

if [[ -n "${CARGO_ACTION_FILTER:-}" ]]; then args+=("${CARGO_ACTION_FILTER}"); fi
append_raw_lines "${CARGO_ACTION_EXTRA_ARGS:-}"

trailing=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  trailing+=("$line")
done <<< "${CARGO_ACTION_TRAILING_ARGS:-}"
if (( ${#trailing[@]} > 0 )); then
  args+=(--)
  args+=("${trailing[@]}")
fi

printf 'cargo'
printf ' %q' "${args[@]}"
printf '\n'
exec cargo "${args[@]}"
