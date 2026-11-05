#!/usr/bin/env python3
"""Measure Cargo freshness on a copied fixture. No remote or global cache writes.

JSON on stdout is evidence, not a hosted Actions or sccache benchmark.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    results = []
    with tempfile.TemporaryDirectory(prefix='cargo-actions-reuse-') as directory:
        crate = Path(directory) / 'crate'
        shutil.copytree(ROOT / 'tests/fixtures/minimal-crate', crate,
                        ignore=shutil.ignore_patterns('target'))
        env = {**os.environ, 'CARGO_TARGET_DIR': str(Path(directory) / 'target'),
               'RUSTC_WRAPPER': '', 'RUSTC_WORKSPACE_WRAPPER': '', 'CARGO_INCREMENTAL': '0'}
        for label, args in [
            ('cold', []), ('warm', []), ('features-changed', ['--features', 'full']),
            ('features-warm', ['--features', 'full']),
            ('profile-changed', ['--release']), ('profile-warm', ['--release']),
        ]:
            command = ['cargo', 'build', '--lib', '--locked', '--offline', '--message-format=json', *args]
            start = time.perf_counter()
            run = subprocess.run(command, cwd=crate, env=env, text=True, capture_output=True)
            artifacts = [json.loads(line) for line in run.stdout.splitlines() if line.startswith('{')]
            artifacts = [x for x in artifacts if x.get('reason') == 'compiler-artifact']
            row = {'case': label, 'argv': command, 'seconds': round(time.perf_counter() - start, 4),
                   'exit': run.returncode, 'fresh': sum(x['fresh'] for x in artifacts),
                   'compiled': sum(not x['fresh'] for x in artifacts), 'stderr': run.stderr}
            results.append(row)
            if run.returncode != 0:
                break
        expected = [(0, 1), (1, 0), (0, 1), (1, 0), (0, 1), (1, 0)]
        passed = len(results) == len(expected) and all(
            (r['fresh'], r['compiled']) == pair and r['exit'] == 0
            for r, pair in zip(results, expected))
        report = {'passed': passed, 'kind': 'local Cargo freshness; no hosted cache restore',
                  'rustc': subprocess.check_output(['rustc', '-Vv'], text=True).strip(),
                  'results': results, 'hosted_cache_hit': None, 'sccache_hits': None}
        print(json.dumps(report, indent=2))
        return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
