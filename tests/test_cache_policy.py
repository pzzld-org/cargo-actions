#!/usr/bin/env python3
"""Execute the real policy script without GitHub or cache network access."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'src/_shared/cache-policy.sh'


def resolve(event='push', ref='refs/heads/main', save='false', compiler='true', branch='main', key='cargo'):
    with tempfile.TemporaryDirectory() as directory:
        output = Path(directory) / 'output'
        env = {**os.environ, 'GITHUB_OUTPUT': str(output), 'GITHUB_EVENT_NAME': event,
               'GITHUB_REF': ref, 'CARGO_ACTION_DEFAULT_BRANCH': branch,
               'CARGO_ACTION_CACHE_SAVE': save, 'CARGO_ACTION_SCCACHE': compiler,
               'CARGO_ACTION_CACHE_KEY': key}
        result = subprocess.run(['bash', str(SCRIPT)], env=env, text=True, capture_output=True)
        values = dict(line.split('=', 1) for line in output.read_text().splitlines()) if output.exists() else {}
        return result, values


class CachePolicy(unittest.TestCase):
    def test_read_only_default(self):
        result, values = resolve()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(values, {'write-enabled': 'false', 'sccache-enabled': 'true', 'sccache-mode': 'READ_ONLY'})

    def test_only_opted_in_default_push_writes(self):
        result, values = resolve(save='true')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(values, {'write-enabled': 'true', 'sccache-enabled': 'true', 'sccache-mode': 'READ_WRITE'})

    def test_configurable_default_branch_and_disabled_compiler(self):
        result, values = resolve(save='true', ref='refs/heads/trunk', branch='trunk', compiler='false')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(values, {'write-enabled': 'true', 'sccache-enabled': 'false', 'sccache-mode': 'disabled'})

    def test_low_trust_events_never_write(self):
        # Includes a privileged ref on a PR target event and missing metadata.
        for event, ref, branch in [
            ('pull_request', 'refs/pull/1/merge', 'main'),
            ('pull_request', 'refs/heads/main', 'main'),
            ('pull_request_target', 'refs/heads/main', 'main'),
            ('workflow_run', 'refs/heads/main', 'main'),
            ('workflow_dispatch', 'refs/heads/main', 'main'),
            ('release', 'refs/tags/v1.0.0', 'main'),
            ('push', 'refs/tags/v1.0.0', 'main'),
            ('push', 'refs/heads/dev/v1.0.0-dev.0', 'main'),
            ('push', 'refs/heads/main', ''),
            ('', '', ''),
        ]:
            with self.subTest(event=event, ref=ref, branch=branch):
                result, values = resolve(event, ref, 'true', branch=branch)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(values, {'write-enabled': 'false', 'sccache-enabled': 'true', 'sccache-mode': 'READ_ONLY'})

    def test_invalid_inputs_fail_before_outputs(self):
        for kwargs in [{'save': 'yes'}, {'compiler': '1'}, {'key': ''}]:
            with self.subTest(kwargs=kwargs):
                result, values = resolve(**kwargs)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(values, {})

    def test_no_shell_evaluation_of_key(self):
        result, values = resolve(key='$(exit 99)\nquoted key')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(values['write-enabled'], 'false')

    def test_composite_wiring(self):
        # Parse metadata with the same YAML parser as the existing schema gate.
        data = subprocess.check_output(['ruby', '-ryaml', '-rjson', '-e',
            'puts JSON.generate(YAML.safe_load(File.read(ARGV[0])))',
            str(ROOT / 'src/setup-rust-cache/action.yml')], text=True)
        action = json.loads(data)
        self.assertEqual(action['inputs']['save-if']['default'], 'false')
        steps = action['runs']['steps']
        rust = next(s for s in steps if s.get('id') == 'rust-cache')
        self.assertEqual(rust['with']['save-if'], '${{ steps.policy.outputs.write-enabled }}')
        self.assertEqual(rust['with']['cache-targets'], 'false')
        self.assertEqual(rust['with']['cache-bin'], 'false')
        for step in steps:
            if 'sccache' in step['name'].lower():
                self.assertEqual(step['if'], "steps.policy.outputs.sccache-enabled == 'true'")
        for name in ['build', 'check', 'test', 'bench', 'clippy', 'doc']:
            text = (ROOT / f'src/cargo-{name}-action/action.yml').read_text()
            self.assertIn('save-if: ${{ inputs.cache-save-if }}', text)
            self.assertIn('sccache: ${{ inputs.cache-sccache }}', text)
            self.assertIn('value: ${{ steps.cache.outputs.write-enabled }}', text)

    def test_sccache_mode_export(self):
        action = json.loads(subprocess.check_output(['ruby', '-ryaml', '-rjson', '-e',
            'puts JSON.generate(YAML.safe_load(File.read(ARGV[0])))',
            str(ROOT / 'src/setup-rust-cache/action.yml')], text=True))
        enable = next(s for s in action['runs']['steps'] if s.get('name') == 'Enable sccache GitHub Actions backend')
        self.assertEqual(enable['env']['SCCACHE_GHA_RW_MODE'], '${{ steps.policy.outputs.sccache-mode }}')
        for save, mode in [('false', 'READ_ONLY'), ('true', 'READ_WRITE')]:
            _, values = resolve(save=save)
            with tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / 'env'
                result = subprocess.run(['bash', '-eu', '-c', enable['run']], capture_output=True,
                    env={**os.environ, 'GITHUB_ENV': str(output),
                         'SCCACHE_GHA_RW_MODE': values['sccache-mode']})
                self.assertEqual(result.returncode, 0)
                self.assertEqual(dict(line.split('=', 1) for line in output.read_text().splitlines()),
                    {'SCCACHE_GHA_RW_MODE': mode, 'RUSTC_WRAPPER': 'sccache', 'SCCACHE_GHA_ENABLED': 'true'})


if __name__ == '__main__':
    unittest.main()
