#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THRESHOLD = 1.0

DERIVED_CACHE_WORKSPACE = "workspaces: ${{ inputs.cache-workspaces || inputs.working-directory }}"

CHECKS = {
    "src/cargo-build-action/action.yml": (
        "author: pzzld-org",
        "uses: $/src/setup-rust-cache",
        DERIVED_CACHE_WORKSPACE,
        "artifact-digest:",
        "64-character lowercase hexadecimal SHA-256 digest",
        "artifact-compression-level:",
        "_shared/resolve-artifact-path.sh",
        "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1",
    ),
    "src/cargo-check-action/action.yml": (
        "uses: $/src/setup-rust-cache",
        DERIVED_CACHE_WORKSPACE,
        "cache-hit:",
        'cargo-command.sh" check',
    ),
    "src/cargo-test-action/action.yml": (
        "default: nextest",
        "default: '0.9.143'",
        "taiki-e/install-action@e67fa11c4b9316fa714ddf0abed07a0c3143b95b # v2.87.4",
        "fallback: cargo-binstall",
        DERIVED_CACHE_WORKSPACE,
        "nextest-no-tests:",
        'cargo-command.sh" test',
    ),
    "src/cargo-bench-action/action.yml": (
        "default: criterion",
        "default: '1.1.0'",
        "taiki-e/install-action@e67fa11c4b9316fa714ddf0abed07a0c3143b95b # v2.87.4",
        "fallback: cargo-binstall",
        DERIVED_CACHE_WORKSPACE,
        "criterion-message-format:",
        'cargo-command.sh" bench',
    ),
    "src/cargo-clippy-action/action.yml": (
        "components: clippy",
        "deny-warnings:",
        "clippy-args:",
        "uses: $/src/setup-rust-cache",
        DERIVED_CACHE_WORKSPACE,
    ),
    "src/cargo-doc-action/action.yml": (
        "document-private-items:",
        "no-deps:",
        "uses: $/src/setup-rust-cache",
        DERIVED_CACHE_WORKSPACE,
    ),
    "src/cargo-fmt-action/action.yml": (
        "components: rustfmt",
        "default: 'true'",
        'cargo-command.sh" fmt',
    ),
    "src/setup-rust-cache/action.yml": (
        "steps.rust-cache.outputs.cache-hit",
        'save-if: ${{ steps.policy.outputs.write-enabled }}',
        "cache-bin: 'false'",
        'version: v0.17.0',
        'SCCACHE_GHA_RW_MODE: ${{ steps.policy.outputs.sccache-mode }}',
        "if: steps.policy.outputs.sccache-enabled == 'true'",
        "sccache-action@fc920bf0ec8de6ee65d409111f7ec508035751ba # v0.0.11",
        "rust-cache@6323deb102c322ba6fcbdcafc7e3dddab59af2b6 # v2.9.2",
    ),
    "src/_shared/cache-policy.sh": (
        'require_bool save-if',
        'require_bool sccache',
        'cache key must not be empty',
        '"${GITHUB_EVENT_NAME:-}" == push',
        '"${GITHUB_REF:-}" == "refs/heads/${CARGO_ACTION_DEFAULT_BRANCH}"',
    ),
    "src/_shared/lib.sh": (
        "require_bool",
        "require_enum",
        "require_uint_range",
        "validate_common_inputs",
    ),
    "src/_shared/nextest-command.sh": (
        "require_enum_if_set nextest-no-tests",
        "fail warn pass",
        "args=(nextest run)",
    ),
    "src/_shared/criterion-command.sh": (
        "require_enum criterion-output-format",
        "criterion quiet verbose bencher",
        "args=(criterion)",
    ),
    "src/_shared/resolve-artifact-path.sh": (
        "CARGO_ACTION_WORKING_DIRECTORY",
        "CARGO_ACTION_ARTIFACT_PATH",
        "CARGO_ACTION_TARGET_DIR",
    ),
    ".github/workflows/ci.yml": (
        "shellcheck@0.11.0",
        "macos-latest",
        "windows-latest",
        "wasm32-unknown-unknown",
        "Validate build outputs",
        "^[0-9a-f]{64}$",
    ),
}


def main() -> int:
    checks: list[dict[str, object]] = []
    for relative, needles in CHECKS.items():
        path = ROOT / relative
        text = path.read_text() if path.is_file() else ""
        for needle in needles:
            checks.append({"artifact": relative, "criterion": needle, "passed": needle in text})

    for name in ("build", "check", "test", "bench", "clippy", "doc"):
        path = ROOT / f"src/cargo-{name}-action/action.yml"
        for needle in ("save-if: ${{ inputs.cache-save-if }}", "sccache: ${{ inputs.cache-sccache }}",
                       "value: ${{ steps.cache.outputs.write-enabled }}"):
            checks.append({"artifact": str(path.relative_to(ROOT)), "criterion": needle,
                           "passed": needle in path.read_text()})

    passed = sum(bool(check["passed"]) for check in checks)
    score = passed / len(checks)
    report = {
        "score": score,
        "threshold": THRESHOLD,
        "passed": passed,
        "total": len(checks),
        "failures": [check for check in checks if not check["passed"]],
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if score >= THRESHOLD else 1


if __name__ == "__main__":
    raise SystemExit(main())
