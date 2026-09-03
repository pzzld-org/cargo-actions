#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACTIONS = {
    "build": ROOT / "src/cargo-build-action/action.yml",
    "check": ROOT / "src/cargo-check-action/action.yml",
    "test": ROOT / "src/cargo-test-action/action.yml",
    "bench": ROOT / "src/cargo-bench-action/action.yml",
    "clippy": ROOT / "src/cargo-clippy-action/action.yml",
    "doc": ROOT / "src/cargo-doc-action/action.yml",
    "fmt": ROOT / "src/cargo-fmt-action/action.yml",
    "cache": ROOT / "src/setup-rust-cache/action.yml",
}

USE_LINE = re.compile(r"^\s*uses:\s*(\S+)(?:\s+#\s*(\S+))?\s*$", re.MULTILINE)
PINNED_EXTERNAL = re.compile(r"^[^@\s]+@[0-9a-f]{40}$")
RELEASE_COMMENT = re.compile(r"^v\d+(?:\.\d+){0,2}(?:[-+][0-9A-Za-z.-]+)?$")


def fail(message: str) -> None:
    raise AssertionError(message)


def read(path: Path) -> str:
    if not path.is_file():
        fail(f"missing {path.relative_to(ROOT)}")
    text = path.read_text()
    if not text.strip():
        fail(f"empty {path.relative_to(ROOT)}")
    return text


def validate_uses(path: Path, text: str, *, allow_local: bool = False) -> None:
    for match in USE_LINE.finditer(text):
        value = match.group(1)
        comment = match.group(2)

        if value.startswith("$/"):
            continue
        if value.startswith("./") or value.startswith("../"):
            if allow_local:
                continue
            fail(f"{path.relative_to(ROOT)}: caller-relative nested action reference is forbidden: {value}")

        if not PINNED_EXTERNAL.fullmatch(value):
            fail(f"{path.relative_to(ROOT)}: external action is not pinned to a 40-character commit SHA: {value}")
        if not comment or not RELEASE_COMMENT.fullmatch(comment):
            fail(f"{path.relative_to(ROOT)}: pinned external action lacks a release-version comment: {value}")


def main() -> int:
    texts = {name: read(path) for name, path in ACTIONS.items()}

    for name, text in texts.items():
        if "runs:\n  using: composite" not in text:
            fail(f"{name}: action is not a composite action")
        if "author: pzzld-org" not in text:
            fail(f"{name}: canonical author metadata missing")
        if re.search(r":\s*\{\s*description:", text):
            fail(f"{name}: flow-style input metadata is forbidden; keep the public API diff-friendly")
        validate_uses(ACTIONS[name], text)

    compile_actions = ("build", "check", "test", "bench", "clippy", "doc")
    for name in compile_actions:
        text = texts[name]
        if not re.search(r"target:\s*\$\{\{ inputs\.target \}\}", text):
            fail(f"{name}: requested Rust target is not installed by setup-rust-toolchain")
        if "uses: $/src/setup-rust-cache" not in text:
            fail(f"{name}: canonical self-referenced cache action is not wired")
        if "mozilla-actions/sccache-action@" in text or "Swatinem/rust-cache@" in text:
            fail(f"{name}: cache implementation leaked into public Cargo action")
        if "CARGO_ACTION_CACHE: ${{ inputs.cache }}" not in text:
            fail(f"{name}: cache input is not validated by the shared runtime")
        if "one complete argument per line" not in text:
            fail(f"{name}: newline-delimited argument contract is undocumented")
        if "cache-hit:" not in text or "steps.cache.outputs.cache-hit" not in text:
            fail(f"{name}: cache-hit composition output missing")
        if "format('cargo-{0}-{1}-{2}'" not in text:
            fail(f"{name}: shared dependency-cache key grammar missing")

    for name in ("build", "check", "clippy", "doc"):
        expected = f'bash "${{GITHUB_ACTION_PATH}}/../_shared/cargo-command.sh" {name}'
        if expected not in texts[name]:
            fail(f"{name}: shared Cargo command runner not wired")

    if "default: nextest" not in texts["test"]:
        fail("test: cargo-nextest is not the default runner")
    if "default: '0.9.143'" not in texts["test"]:
        fail("test: tested cargo-nextest version is not pinned")
    if "taiki-e/install-action@e67fa11c4b9316fa714ddf0abed07a0c3143b95b # v2.87.4" not in texts["test"]:
        fail("test: current pinned taiki-e/install-action missing")
    if "fallback: cargo-binstall" not in texts["test"]:
        fail("test: cargo-binstall fallback missing")
    if '_shared/nextest-command.sh' not in texts["test"] or '_shared/cargo-command.sh" test' not in texts["test"]:
        fail("test: nextest/cargo runner dispatch missing")
    expected_no_tests_contract = (
        "  nextest-no-tests:\n"
        "    description: Behavior when no tests match. Accepted values are fail, warn, and pass.\n"
    )
    if expected_no_tests_contract not in texts["test"]:
        fail("test: nextest --no-tests documentation must expose exactly fail, warn, and pass")

    if "default: criterion" not in texts["bench"]:
        fail("bench: cargo-criterion is not the default runner")
    if "default: '1.1.0'" not in texts["bench"]:
        fail("bench: tested cargo-criterion version is not pinned")
    if "taiki-e/install-action@e67fa11c4b9316fa714ddf0abed07a0c3143b95b # v2.87.4" not in texts["bench"]:
        fail("bench: current pinned taiki-e/install-action missing")
    if "fallback: cargo-binstall" not in texts["bench"]:
        fail("bench: cargo-binstall fallback missing")
    if '_shared/criterion-command.sh' not in texts["bench"] or '_shared/cargo-command.sh" bench' not in texts["bench"]:
        fail("bench: criterion/cargo runner dispatch missing")

    if "components: clippy" not in texts["clippy"]:
        fail("clippy: clippy component is not installed")
    if "components: rustfmt" not in texts["fmt"]:
        fail("fmt: rustfmt component is not installed")

    build = texts["build"]
    for output in ("artifact-id", "artifact-url", "artifact-digest", "artifact-path"):
        if f"  {output}:" not in build:
            fail(f"build: {output} output missing")
    for input_name in (
        "artifact-compression-level",
        "artifact-overwrite",
        "artifact-include-hidden-files",
        "artifact-archive",
    ):
        if f"  {input_name}:" not in build:
            fail(f"build: {input_name} input missing")
    if "_shared/resolve-artifact-path.sh" not in build:
        fail("build: artifact path resolver missing")
    if "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1" not in build:
        fail("build: pinned upload-artifact v7.0.1 missing")

    cache = texts["cache"]
    if "mozilla-actions/sccache-action@fc920bf0ec8de6ee65d409111f7ec508035751ba # v0.0.11" not in cache:
        fail("cache: pinned sccache action missing")
    if "Swatinem/rust-cache@6323deb102c322ba6fcbdcafc7e3dddab59af2b6 # v2.9.2" not in cache:
        fail("cache: pinned rust-cache action missing")
    if "id: rust-cache" not in cache or "steps.rust-cache.outputs.cache-hit" not in cache:
        fail("cache: cache-hit output is not wired")
    if "cache key must not be empty" not in cache:
        fail("cache: required key is not enforced at runtime")

    shared = read(ROOT / "src/_shared/cargo-command.sh")
    library = read(ROOT / "src/_shared/lib.sh")
    resolver = read(ROOT / "src/_shared/resolve-artifact-path.sh")
    for primitive in (
        "append_common_package_args",
        "append_common_target_args",
        "append_common_feature_args",
        "append_common_compile_args",
        "append_raw_lines",
        'exec cargo "${args[@]}"',
    ):
        if primitive not in shared:
            fail(f"shared runner is missing primitive: {primitive}")
    for primitive in ("require_bool", "require_enum", "require_uint_range", "validate_common_inputs"):
        if primitive not in library:
            fail(f"shared validation library is missing primitive: {primitive}")
    if "CARGO_ACTION_WORKING_DIRECTORY" not in resolver or "[A-Za-z]:" not in resolver:
        fail("artifact resolver does not encode cross-platform path semantics")

    for path in (ROOT / "src/_shared").glob("*.sh"):
        if "eval " in read(path):
            fail(f"{path.relative_to(ROOT)}: caller-provided arguments must never be shell-evaluated")

    workflow = ROOT / ".github/workflows/ci.yml"
    workflow_text = read(workflow)
    validate_uses(workflow, workflow_text, allow_local=True)
    for expected in ("macos-latest", "windows-latest", "wasm32-unknown-unknown", "shellcheck@0.11.0"):
        if expected not in workflow_text:
            fail(f"CI: missing hardening lane or tool: {expected}")

    print("action metadata contracts: ok")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"contract failure: {exc}", file=sys.stderr)
        raise SystemExit(1)
