#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/cargo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${CARGO_ARGS_LOG:?}"
SH
chmod +x "$tmp/cargo"
export PATH="$tmp:$PATH"
export CARGO_ARGS_LOG="$tmp/args.log"

assert_args() {
  local name="$1"
  shift
  local expected="$tmp/expected"
  printf '%s\n' "$@" > "$expected"
  if ! diff -u "$expected" "$CARGO_ARGS_LOG"; then
    echo "runner argv test failed: $name" >&2
    exit 1
  fi
}

CARGO_ACTION_WORKSPACE=true \
CARGO_ACTION_FEATURES=full \
CARGO_ACTION_LOCKED=true \
CARGO_ACTION_COLOR=always \
CARGO_ACTION_NO_RUN=true \
CARGO_ACTION_FILTER=parser \
NEXTEST_ACTION_NO_TESTS=warn \
CARGO_ACTION_TRAILING_ARGS=--exact \
bash "$root/src/_shared/nextest-command.sh" >/dev/null
assert_args nextest \
  nextest run \
  --workspace \
  --features full \
  --locked \
  --color always \
  --no-run \
  --no-tests warn \
  parser \
  -- \
  --exact

CARGO_ACTION_PACKAGE=cargo-actions-fixture \
CARGO_ACTION_BENCH=smoke \
CARGO_ACTION_LOCKED=true \
CARGO_ACTION_COLOR=always \
CARGO_ACTION_NO_RUN=true \
CRITERION_ACTION_OUTPUT_FORMAT=criterion \
bash "$root/src/_shared/criterion-command.sh" >/dev/null
assert_args criterion \
  criterion \
  --package cargo-actions-fixture \
  --bench smoke \
  --locked \
  --color always \
  --no-run \
  --output-format criterion

if CARGO_ACTION_PROFILE=custom bash "$root/src/_shared/criterion-command.sh" >/dev/null 2>"$tmp/err"; then
  echo "criterion custom profile should fail" >&2
  exit 1
fi
grep -F 'profile=custom is not supported by cargo-criterion' "$tmp/err" >/dev/null

if NEXTEST_ACTION_NO_TESTS=auto bash "$root/src/_shared/nextest-command.sh" >/dev/null 2>"$tmp/err"; then
  echo "nextest invalid no-tests mode should fail" >&2
  exit 1
fi
grep -F 'nextest-no-tests must be one of: fail warn pass (got: auto)' "$tmp/err" >/dev/null

if NEXTEST_ACTION_TEST_THREADS=zero bash "$root/src/_shared/nextest-command.sh" >/dev/null 2>"$tmp/err"; then
  echo "nextest invalid test-threads should fail" >&2
  exit 1
fi
grep -F 'nextest-test-threads must be num-cpus or a non-zero integer' "$tmp/err" >/dev/null

if CRITERION_ACTION_OUTPUT_FORMAT=json bash "$root/src/_shared/criterion-command.sh" >/dev/null 2>"$tmp/err"; then
  echo "criterion invalid output format should fail" >&2
  exit 1
fi
grep -F 'criterion-output-format must be one of: criterion quiet verbose bencher (got: json)' "$tmp/err" >/dev/null

if CRITERION_ACTION_DEBUG=yes bash "$root/src/_shared/criterion-command.sh" >/dev/null 2>"$tmp/err"; then
  echo "criterion non-canonical boolean should fail" >&2
  exit 1
fi
grep -F 'criterion-debug must be true or false (got: yes)' "$tmp/err" >/dev/null

printf 'tool runner argv tests: ok\n'
