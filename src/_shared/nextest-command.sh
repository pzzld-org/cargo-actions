#!/usr/bin/env bash
set -euo pipefail

SHARED_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SHARED_DIR
# shellcheck source=lib.sh
source "${SHARED_DIR}/lib.sh"

validate_common_inputs
require_uint_if_set nextest-retries "${NEXTEST_ACTION_RETRIES:-}"
require_enum_if_set nextest-run-ignored "${NEXTEST_ACTION_RUN_IGNORED:-}" default only all
require_enum_if_set nextest-no-tests "${NEXTEST_ACTION_NO_TESTS:-}" fail warn pass

if [[ -n "${NEXTEST_ACTION_TEST_THREADS:-}" ]] \
  && [[ "${NEXTEST_ACTION_TEST_THREADS}" != "num-cpus" ]] \
  && ! [[ "${NEXTEST_ACTION_TEST_THREADS}" =~ ^-?[1-9][0-9]*$ ]]; then
  cargo_actions_die "nextest-test-threads must be num-cpus or a non-zero integer (got: ${NEXTEST_ACTION_TEST_THREADS})"
fi

if is_true "${CARGO_ACTION_KEEP_GOING:-false}"; then
  cargo_actions_die "keep-going is not supported by cargo nextest run; use no-fail-fast instead"
fi
if is_true "${CARGO_ACTION_FUTURE_INCOMPAT_REPORT:-false}"; then
  cargo_actions_die "future-incompat-report is not supported by cargo nextest run"
fi
if is_true "${CARGO_ACTION_QUIET:-false}"; then
  cargo_actions_die "quiet=true is not supported by cargo nextest run"
fi

args=(nextest run)

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

if is_true "${CARGO_ACTION_ALL_FEATURES:-false}"; then args+=(--all-features); fi
if is_true "${CARGO_ACTION_NO_DEFAULT_FEATURES:-false}"; then args+=(--no-default-features); fi
case "${CARGO_ACTION_FEATURES:-}" in
  ""|default) ;;
  all)
    if ! is_true "${CARGO_ACTION_ALL_FEATURES:-false}"; then args+=(--all-features); fi
    ;;
  *) args+=(--features "${CARGO_ACTION_FEATURES}") ;;
esac

if [[ -n "${CARGO_ACTION_JOBS:-}" ]]; then args+=(--build-jobs "${CARGO_ACTION_JOBS}"); fi
if is_true "${CARGO_ACTION_RELEASE:-false}"; then
  args+=(--release)
elif [[ -n "${CARGO_ACTION_PROFILE:-}" ]]; then
  args+=(--cargo-profile "${CARGO_ACTION_PROFILE}")
fi
if [[ -n "${CARGO_ACTION_TARGET:-}" ]]; then args+=(--target "${CARGO_ACTION_TARGET}"); fi
if [[ -n "${CARGO_ACTION_TARGET_DIR:-}" ]]; then args+=(--target-dir "${CARGO_ACTION_TARGET_DIR}"); fi
if [[ -n "${CARGO_ACTION_MANIFEST_PATH:-}" ]]; then args+=(--manifest-path "${CARGO_ACTION_MANIFEST_PATH}"); fi

if is_true "${CARGO_ACTION_LOCKED:-true}"; then args+=(--locked); fi
if is_true "${CARGO_ACTION_FROZEN:-false}"; then args+=(--frozen); fi
if is_true "${CARGO_ACTION_OFFLINE:-false}"; then args+=(--offline); fi
if is_true "${CARGO_ACTION_IGNORE_RUST_VERSION:-false}"; then args+=(--ignore-rust-version); fi
append_lines --config "${CARGO_ACTION_CONFIG:-}"

if is_true "${CARGO_ACTION_VERBOSE:-false}"; then args+=(--verbose); fi
if [[ -n "${CARGO_ACTION_COLOR:-always}" ]]; then args+=(--color "${CARGO_ACTION_COLOR:-always}"); fi
if [[ -n "${CARGO_ACTION_MESSAGE_FORMAT:-}" ]]; then args+=(--cargo-message-format "${CARGO_ACTION_MESSAGE_FORMAT}"); fi

if is_true "${CARGO_ACTION_NO_RUN:-false}"; then args+=(--no-run); fi
if is_true "${CARGO_ACTION_NO_FAIL_FAST:-false}"; then args+=(--no-fail-fast); fi
if [[ -n "${NEXTEST_ACTION_PROFILE:-}" ]]; then args+=(--profile "${NEXTEST_ACTION_PROFILE}"); fi
if [[ -n "${NEXTEST_ACTION_RETRIES:-}" ]]; then args+=(--retries "${NEXTEST_ACTION_RETRIES}"); fi
if [[ -n "${NEXTEST_ACTION_TEST_THREADS:-}" ]]; then args+=(--test-threads "${NEXTEST_ACTION_TEST_THREADS}"); fi
append_lines --filterset "${NEXTEST_ACTION_FILTERSET:-}"
if [[ -n "${NEXTEST_ACTION_PARTITION:-}" ]]; then args+=(--partition "${NEXTEST_ACTION_PARTITION}"); fi
if [[ -n "${NEXTEST_ACTION_RUN_IGNORED:-}" ]]; then args+=(--run-ignored "${NEXTEST_ACTION_RUN_IGNORED}"); fi
if [[ -n "${NEXTEST_ACTION_NO_TESTS:-}" ]]; then args+=(--no-tests "${NEXTEST_ACTION_NO_TESTS}"); fi

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
