#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "cargo-build-action": ("build", "target", "features", "artifact"),
    "cargo-check-action": ("check", "target", "features", "cache"),
    "cargo-test-action": ("test", "filter", "test-args", "no-run"),
    "cargo-bench-action": ("bench", "filter", "bench-args", "no-run"),
    "cargo-clippy-action": ("clippy", "clippy-args", "deny-warnings", "no-deps"),
    "cargo-doc-action": ("doc", "document-private-items", "no-deps", "target"),
    "cargo-fmt-action": ("fmt", "check", "workspace", "rustfmt"),
}

THRESHOLD = 1.0


def main() -> int:
    checks: list[dict[str, object]] = []

    for directory, needles in EXPECTED.items():
        path = ROOT / "src" / directory / "action.yml"
        text = path.read_text() if path.is_file() else ""
        for needle in needles:
            checks.append({"action": directory, "criterion": needle, "passed": needle in text})

    shared = ROOT / "src/_shared/cargo-command.sh"
    shared_text = shared.read_text() if shared.is_file() else ""
    for needle in (
        "append_common_package_args",
        "append_common_target_args",
        "append_common_feature_args",
        "append_common_compile_args",
        "append_common_manifest_args",
        "append_raw_lines",
        'exec cargo "${args[@]}"',
    ):
        checks.append({"action": "_shared", "criterion": needle, "passed": needle in shared_text})

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
