#!/usr/bin/env bash
# filetree.sh - emit a JSON inventory of the Axiom workspace
#
# Writes `.shepherd/filetree.json` with an entry per tracked file that matters
# for navigation (Rust sources, Cargo manifests, WIT contracts, build scripts).
# The initialized, root-pinned RSPM submodule is part of the same inventory.
# Each entry carries:
#   path, kind, crate, loc, bytes
#
# `generated_at` records wall-clock generation time. Freshness normalizes only
# that field; the sorted `files` array is the deterministic authority.
#
# kind is one of: rs, toml, wit, sh, py, json, md, other
# crate is the workspace member the file belongs to (or "" for root files)
#
# Usage:  scripts/filetree.sh [--stdout]
#
# Defaults to writing .shepherd/filetree.json. Pass --stdout to dump to stdout.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CANONICAL_OUT="$REPO/.shepherd/filetree.json"

case "${1:-}" in
    "")
        OUT="$CANONICAL_OUT"
        ;;
    --stdout)
        OUT="/dev/stdout"
        ;;
    *)
        echo "usage: scripts/filetree.sh [--stdout]" >&2
        exit 2
        ;;
esac

render_filetree() {
    python3 - "$REPO" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

REPO = Path(sys.argv[1])
RSPM_PATH = PurePosixPath("clients/rspm")
TRACKED_PATHSPECS = ("*.rs", "*.toml", "*.wit", "build.rs")
EXCLUDED_DIRECTORIES = {
    ".artifacts",
    ".shepherd",
    ".worktrees",
    "node_modules",
    "target",
}


def git_bytes(root: Path, *arguments: str) -> bytes:
    completed = subprocess.run(
        ("git", *arguments),
        cwd=root,
        check=True,
        capture_output=True,
    )
    return completed.stdout


def tracked_paths(root: Path, prefix: PurePosixPath | None = None) -> list[str]:
    raw_paths = git_bytes(root, "ls-files", "-z", "--", *TRACKED_PATHSPECS)
    paths: list[str] = []
    for raw_path in raw_paths.split(b"\0"):
        if not raw_path:
            continue
        relative = PurePosixPath(raw_path.decode("utf-8", "surrogateescape"))
        path = relative if prefix is None else prefix / relative
        if EXCLUDED_DIRECTORIES.isdisjoint(path.parts):
            paths.append(str(path))
    return paths


def root_rspm_gitlink_oid() -> str | None:
    stage = git_bytes(REPO, "ls-files", "--stage", "--", str(RSPM_PATH))
    gitlink_oids = [
        fields[1].decode("ascii")
        for line in stage.splitlines()
        if len(fields := line.split(maxsplit=3)) == 4 and fields[0] == b"160000"
    ]
    if not gitlink_oids:
        return None
    if len(gitlink_oids) != 1:
        raise SystemExit("filetree: clients/rspm has unresolved gitlink stages")
    return gitlink_oids[0]


def require_pinned_rspm(expected_oid: str) -> Path:
    rspm = REPO / RSPM_PATH
    if not rspm.is_dir():
        raise SystemExit(
            "filetree: clients/rspm is a tracked gitlink but is not initialized"
        )
    top_level = subprocess.run(
        ("git", "rev-parse", "--show-toplevel"),
        cwd=rspm,
        check=False,
        capture_output=True,
        text=True,
    )
    if (
        top_level.returncode != 0
        or Path(top_level.stdout.strip()).resolve() != rspm.resolve()
    ):
        raise SystemExit(
            "filetree: clients/rspm is a tracked gitlink but is not initialized"
        )
    head = subprocess.run(
        ("git", "rev-parse", "HEAD"),
        cwd=rspm,
        check=False,
        capture_output=True,
        text=True,
    )
    if head.returncode != 0:
        raise SystemExit(
            "filetree: clients/rspm is a tracked gitlink but has no checked-out HEAD"
        )
    actual_oid = head.stdout.strip()
    if actual_oid != expected_oid:
        raise SystemExit(
            "filetree: clients/rspm HEAD differs from the root gitlink "
            f"({actual_oid} != {expected_oid})"
        )
    return rspm


def kind_of(path: str) -> str:
    suffix = PurePosixPath(path).suffix
    return {
        ".json": "json",
        ".md": "md",
        ".py": "py",
        ".rs": "rs",
        ".sh": "sh",
        ".toml": "toml",
        ".wit": "wit",
    }.get(suffix, "other")


def crate_of(path: str) -> str:
    parts = PurePosixPath(path).parts
    if len(parts) >= 2 and parts[0] in {"bin", "clients", "cmp", "crates"}:
        return "/".join(parts[:2])
    return ""


def inventory_row(path: str) -> dict[str, str | int] | None:
    absolute = REPO / path
    if not absolute.is_file():
        return None
    content = absolute.read_bytes()
    return {
        "path": path,
        "kind": kind_of(path),
        "crate": crate_of(path),
        "loc": content.count(b"\n"),
        "bytes": len(content),
    }


paths = tracked_paths(REPO)
rspm_oid = root_rspm_gitlink_oid()
if rspm_oid is not None:
    paths.extend(tracked_paths(require_pinned_rspm(rspm_oid), RSPM_PATH))

rows = [
    row
    for path in sorted(
        set(paths),
        key=lambda candidate: candidate.encode("utf-8", "surrogateescape"),
    )
    if (row := inventory_row(path)) is not None
]
generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

sys.stdout.write("{\n")
sys.stdout.write(f'  "generated_at": {json.dumps(generated_at)},\n')
sys.stdout.write('  "files": [\n')
for index, row in enumerate(rows):
    separator = "" if index == 0 else ",\n"
    encoded = json.dumps(row, ensure_ascii=True, separators=(",", ":"))
    sys.stdout.write(f"{separator}    {encoded}")
sys.stdout.write("\n  ]\n}\n")
PY
}

if [[ "$OUT" == "/dev/stdout" ]]; then
    render_filetree
    exit 0
fi

mkdir -p -- "$(dirname "$OUT")"
temporary="$(mktemp "${TMPDIR:-/tmp}/axiom-filetree.XXXXXX")"
trap 'rm -f -- "$temporary"' EXIT
render_filetree > "$temporary"
chmod 0644 "$temporary"
mv -f -- "$temporary" "$OUT"
trap - EXIT

count="$(grep -c '"path":' "$OUT" || true)"
echo "wrote $OUT ($count entries)" >&2
