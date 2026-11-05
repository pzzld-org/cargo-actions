#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="${ROOT}/src/_shared/resolve-artifact-path.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

resolve() {
  local working_directory="$1"
  local artifact_path="$2"
  local target_dir="$3"
  export GITHUB_OUTPUT="${TMP}/output"
  : > "${GITHUB_OUTPUT}"
  CARGO_ACTION_WORKING_DIRECTORY="$working_directory" \
  CARGO_ACTION_ARTIFACT_PATH="$artifact_path" \
  CARGO_ACTION_TARGET_DIR="$target_dir" \
    bash "${RUNNER}" >/dev/null
  sed -n 's/^path=//p' "${GITHUB_OUTPUT}"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local name="$3"
  if [[ "$expected" != "$actual" ]]; then
    printf '%s: expected <%s>, got <%s>\n' "$name" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_eq 'crate/target' "$(resolve crate '' '')" default-target
assert_eq 'crate/.target/ci' "$(resolve crate '' '.target/ci')" relative-target-dir
assert_eq 'crate/dist/*.bin' "$(resolve crate 'dist/*.bin' '')" relative-artifact-path
assert_eq '/tmp/cargo-target' "$(resolve crate '' '/tmp/cargo-target')" unix-absolute-target
assert_eq 'C:\temp\cargo-target' "$(resolve crate '' 'C:\temp\cargo-target')" windows-absolute-target
assert_eq '\\server\share\cargo-target' "$(resolve crate '' '\\server\share\cargo-target')" windows-unc-target
assert_eq 'target' "$(resolve . '' '')" root-working-directory

if CARGO_ACTION_WORKING_DIRECTORY='' CARGO_ACTION_ARTIFACT_PATH='' CARGO_ACTION_TARGET_DIR='' GITHUB_OUTPUT="${TMP}/output" bash "${RUNNER}" >/dev/null 2>"${TMP}/err"; then
  echo 'expected empty working-directory to fail' >&2
  exit 1
fi
grep -F 'working-directory must not be empty' "${TMP}/err" >/dev/null

printf 'artifact path contract: ok\n'
