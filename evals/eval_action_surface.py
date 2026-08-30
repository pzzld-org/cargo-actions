#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "cargo-build-action": ("build", "target", "features", "artifact"),
    "cargo-check-action": ("check", "target", "features", "cache"),
    "cargo-test-action": ("runner", "default: nextest", "cargo-nextest", "nextest-profile", "test-args", 'cargo) exec bash "${GITHUB_ACTION_PATH}/../_shared/cargo-command.sh" test'),
    "cargo-bench-action": ("runner", "default: criterion", "cargo-criterion", "criterion-output-format", "bench-args", 'cargo) exec bash "${GITHUB_ACTION_PATH}/../_shared/cargo-command.sh" bench'),
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

    shared_checks = {
        "cargo-command.sh": (
            "append_common_package_args",
            "append_common_target_args",
            "append_common_feature_args",
            'exec cargo "${args[@]}"',
        ),
        "nextest-command.sh": ("args=(nextest run)", "--build-jobs", "--filterset", 'exec cargo "${args[@]}"'),
        "criterion-command.sh": ("args=(criterion)", "--output-format", "--criterion-manifest-path", 'exec cargo "${args[@]}"'),
    }
    for filename, needles in shared_checks.items():
        path = ROOT / "src/_shared" / filename
        text = path.read_text() if path.is_file() else ""
        for needle in needles:
            checks.append({"action": f"_shared/{filename}", "criterion": needle, "passed": needle in text})

    for directory in ("cargo-test-action", "cargo-bench-action"):
        text = (ROOT / "src" / directory / "action.yml").read_text()
        for needle in (
            "taiki-e/install-action@1ed6d7be6168f6c9046541087ff549b6bc581fdf",
            "fallback: cargo-binstall",
        ):
            checks.append({"action": directory, "criterion": needle, "passed": needle in text})

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
