#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="${ROOT}/src/_shared/cargo-command.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cat > "${TMP}/cargo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${CARGO_CAPTURE:?}"
printf '%s\n' "$@" > "${CARGO_CAPTURE}"
EOF
chmod +x "${TMP}/cargo"
export PATH="${TMP}:${PATH}"

assert_capture() {
  local name="$1"
  shift
  local expected="${TMP}/${name}.expected"
  printf '%s\n' "$@" > "${expected}"
  diff -u "${expected}" "${CARGO_CAPTURE}"
}

reset_env() {
  for var in $(env | sed -n 's/^\(CARGO_ACTION_[A-Z0-9_]*\)=.*/\1/p'); do
    unset "$var"
  done
  export CARGO_CAPTURE="${TMP}/capture"
}

reset_env
CARGO_ACTION_LOCKED=true CARGO_ACTION_COLOR=always bash "${RUNNER}" build
assert_capture default-build build --locked --color always

reset_env
export CARGO_ACTION_WORKSPACE=true
export CARGO_ACTION_EXCLUDE=$'fixture-skip\nfixture-other'
export CARGO_ACTION_FEATURES='serde full'
export CARGO_ACTION_ALL_TARGETS=true
export CARGO_ACTION_TARGET='wasm32-wasip2'
export CARGO_ACTION_JOBS=2
export CARGO_ACTION_KEEP_GOING=true
export CARGO_ACTION_PROFILE=ci
export CARGO_ACTION_TARGET_DIR=.target/ci
export CARGO_ACTION_MANIFEST_PATH=Cargo.toml
export CARGO_ACTION_LOCKED=true
export CARGO_ACTION_OFFLINE=true
export CARGO_ACTION_IGNORE_RUST_VERSION=true
export CARGO_ACTION_MESSAGE_FORMAT=short
export CARGO_ACTION_EXTRA_ARGS=$'--timings\n--config\nnet.retry=2'
bash "${RUNNER}" build
assert_capture configured-build \
  build \
  --workspace \
  --exclude fixture-skip \
  --exclude fixture-other \
  --all-targets \
  --features 'serde full' \
  --jobs 2 \
  --keep-going \
  --profile ci \
  --target wasm32-wasip2 \
  --target-dir .target/ci \
  --manifest-path Cargo.toml \
  --locked \
  --offline \
  --ignore-rust-version \
  --color always \
  --message-format short \
  --timings \
  --config \
  net.retry=2

reset_env
export CARGO_ACTION_PACKAGE=fixture
export CARGO_ACTION_NO_RUN=true
export CARGO_ACTION_NO_FAIL_FAST=true
export CARGO_ACTION_LOCKED=false
export CARGO_ACTION_COLOR=never
export CARGO_ACTION_TRAILING_ARGS=$'--nocapture\n--test-threads=1'
bash "${RUNNER}" test
assert_capture test-forwarding \
  test \
  --package fixture \
  --color never \
  --no-run \
  --no-fail-fast \
  -- \
  --nocapture \
  --test-threads=1

reset_env
export CARGO_ACTION_ALL_FEATURES=true
export CARGO_ACTION_DENY_WARNINGS=true
export CARGO_ACTION_LOCKED=true
export CARGO_ACTION_COLOR=always
export CARGO_ACTION_TRAILING_ARGS=$'-W\nclippy::pedantic'
bash "${RUNNER}" clippy
assert_capture clippy-forwarding \
  clippy \
  --all-features \
  --locked \
  --color always \
  -- \
  -W \
  clippy::pedantic \
  -D \
  warnings

reset_env
export CARGO_ACTION_WORKSPACE=true
export CARGO_ACTION_CHECK=true
export CARGO_ACTION_MESSAGE_FORMAT=short
export CARGO_ACTION_EXTRA_ARGS=$'--config-path\nrustfmt.toml'
bash "${RUNNER}" fmt
assert_capture fmt \
  fmt \
  --all \
  --check \
  --message-format short \
  --config-path \
  rustfmt.toml

reset_env
export CARGO_ACTION_RELEASE=true
export CARGO_ACTION_PROFILE=ci
if bash "${RUNNER}" build >"${TMP}/invalid.out" 2>"${TMP}/invalid.err"; then
  echo "expected release/profile conflict to fail" >&2
  exit 1
fi
grep -F 'release=true and profile=ci are mutually exclusive' "${TMP}/invalid.err" >/dev/null

reset_env
export CARGO_ACTION_VERBOSE=true
export CARGO_ACTION_QUIET=true
if bash "${RUNNER}" check >"${TMP}/invalid.out" 2>"${TMP}/invalid.err"; then
  echo "expected verbose/quiet conflict to fail" >&2
  exit 1
fi
grep -F 'verbose=true and quiet=true are mutually exclusive' "${TMP}/invalid.err" >/dev/null

echo "cargo-command contract: ok"
