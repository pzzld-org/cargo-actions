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

PINNED_USE = re.compile(r"^\s*uses:\s*([^@\s]+)@([0-9a-f]{40})(?:\s+#.*)?$", re.MULTILINE)
ANY_USE = re.compile(r"^\s*uses:\s*(\S+)(?:\s+#.*)?$", re.MULTILINE)


def fail(message: str) -> None:
    raise AssertionError(message)


def read(path: Path) -> str:
    if not path.is_file():
        fail(f"missing {path.relative_to(ROOT)}")
    text = path.read_text()
    if not text.strip():
        fail(f"empty {path.relative_to(ROOT)}")
    return text


def main() -> int:
    texts = {name: read(path) for name, path in ACTIONS.items()}

    for name, text in texts.items():
        if "runs:\n  using: composite" not in text:
            fail(f"{name}: action is not a composite action")
        for match in ANY_USE.finditer(text):
            value = match.group(1)
            if value.startswith("./") or value.startswith("../"):
                fail(f"{name}: caller-relative nested action reference is forbidden: {value}")
            if "@" in value and not PINNED_USE.search(match.group(0)):
                fail(f"{name}: third-party action is not pinned to a 40-character commit SHA: {value}")

    compile_actions = ("build", "check", "test", "bench", "clippy", "doc")
    for name in compile_actions:
        text = texts[name]
        if not re.search(r"target:\s*['\"]?\$\{\{ inputs\.target \}\}['\"]?", text):
            fail(f"{name}: requested Rust target is not installed by setup-rust-toolchain")
        if "mozilla-actions/sccache-action@" not in text:
            fail(f"{name}: sccache layer missing")
        if "Swatinem/rust-cache@" not in text:
            fail(f"{name}: Rust dependency cache layer missing")
        if "one complete argument per line" not in text:
            fail(f"{name}: extra-argument contract is undocumented")

    for name in ("build", "check", "clippy", "doc"):
        expected = f'bash "${{GITHUB_ACTION_PATH}}/../_shared/cargo-command.sh" {name}'
        if expected not in texts[name]:
            fail(f"{name}: shared Cargo command runner not wired")

    if "default: nextest" not in texts["test"]:
        fail("test: cargo-nextest is not the default runner")
    if "taiki-e/install-action@1ed6d7be6168f6c9046541087ff549b6bc581fdf" not in texts["test"]:
        fail("test: pinned taiki-e/install-action missing")
    if "fallback: cargo-binstall" not in texts["test"]:
        fail("test: cargo-binstall fallback missing")
    if '_shared/nextest-command.sh' not in texts["test"] or '_shared/cargo-command.sh" test' not in texts["test"]:
        fail("test: nextest/cargo runner dispatch missing")

    if "default: criterion" not in texts["bench"]:
        fail("bench: cargo-criterion is not the default runner")
    if "taiki-e/install-action@1ed6d7be6168f6c9046541087ff549b6bc581fdf" not in texts["bench"]:
        fail("bench: pinned taiki-e/install-action missing")
    if "fallback: cargo-binstall" not in texts["bench"]:
        fail("bench: cargo-binstall fallback missing")
    if '_shared/criterion-command.sh' not in texts["bench"] or '_shared/cargo-command.sh" bench' not in texts["bench"]:
        fail("bench: criterion/cargo runner dispatch missing")

    if "components: clippy" not in texts["clippy"]:
        fail("clippy: clippy component is not installed")
    if "components: rustfmt" not in texts["fmt"]:
        fail("fmt: rustfmt component is not installed")
    if "actions/upload-artifact@" not in texts["build"]:
        fail("build: artifact publishing support missing")
    if "CARGO_ACTION_TRAILING_ARGS: ${{ inputs.test-args }}" not in texts["test"]:
        fail("test: test runner argument forwarding missing")
    if "CARGO_ACTION_TRAILING_ARGS: ${{ inputs.bench-args }}" not in texts["bench"]:
        fail("bench: benchmark runner argument forwarding missing")
    if "CARGO_ACTION_TRAILING_ARGS: ${{ inputs.clippy-args }}" not in texts["clippy"]:
        fail("clippy: lint argument forwarding missing")
    if "CARGO_ACTION_DENY_WARNINGS: ${{ inputs.deny-warnings }}" not in texts["clippy"]:
        fail("clippy: deny-warnings contract missing")

    shared = read(ROOT / "src/_shared/cargo-command.sh")
    for primitive in (
        "append_common_package_args",
        "append_common_target_args",
        "append_common_feature_args",
        "append_common_compile_args",
        "append_common_manifest_args",
        "append_raw_lines",
        'exec cargo "${args[@]}"',
    ):
        if primitive not in shared:
            fail(f"shared runner is missing primitive: {primitive}")
    if "eval " in shared:
        fail("shared runner must not shell-evaluate caller-provided arguments")

    nextest = read(ROOT / "src/_shared/nextest-command.sh")
    criterion = read(ROOT / "src/_shared/criterion-command.sh")
    for name, script, prefix in (
        ("nextest", nextest, "args=(nextest run)"),
        ("criterion", criterion, "args=(criterion)"),
    ):
        if prefix not in script:
            fail(f"{name}: runner prefix missing")
        if 'exec cargo "${args[@]}"' not in script:
            fail(f"{name}: runner does not exec Cargo directly")
        if "eval " in script:
            fail(f"{name}: runner must not shell-evaluate caller-provided arguments")

    print("action metadata contracts: ok")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"contract failure: {exc}", file=sys.stderr)
        raise SystemExit(1)
