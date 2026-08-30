#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/cargo" <<'SH'
#!/usr/bin/env bash
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
CARGO_ACTION_TRAILING_ARGS=--exact \
bash "$root/src/_shared/nextest-command.sh" >/dev/null
assert_args nextest \
  nextest run \
  --workspace \
  --features full \
  --locked \
  --color always \
  --no-run \
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

if CARGO_ACTION_PROFILE=custom bash "$root/src/_shared/criterion-command.sh" >/dev/null 2>&1; then
  echo "criterion custom profile should fail" >&2
  exit 1
fi

printf 'tool runner argv tests: ok\n'
