# Agents Home

Maintain the contents of this file according to the workspace, allowing the root `AGENTS.md` and `CLAUDE.md` policy files to remain stable.

## Workspace

### Purpose

`cargo-actions` provides externally consumable composite GitHub Actions for common Cargo commands. Caller workflows own CI orchestration and matrices. Public actions own one Cargo execution contract.

### Layout

```text
src/
  _shared/lib.sh
  _shared/cargo-command.sh
  _shared/nextest-command.sh
  _shared/criterion-command.sh
  _shared/resolve-artifact-path.sh
  cargo-build-action/action.yml
  cargo-check-action/action.yml
  cargo-test-action/action.yml
  cargo-bench-action/action.yml
  cargo-clippy-action/action.yml
  cargo-doc-action/action.yml
  cargo-fmt-action/action.yml
  setup-rust-cache/action.yml
tests/
  fixtures/minimal-crate/
  test-action-yaml.rb
  test-artifact-path.sh
  test-cargo-command.sh
  test-tool-runners.sh
  test_action_contracts.py
evals/
  eval_action_surface.py
.github/workflows/
  ci.yml
```

### Contracts

- Do not put matrices, checkout/ref policy, or repository-specific post-build behavior inside public Cargo actions.
- Public actions must not use caller-relative nested `uses: ./...` or `uses: ../...` references.
- Same-repository composition uses GitHub's `$/...` reference so the nested action resolves at the running action revision. This targets GitHub.com; GHES does not support the syntax.
- Third-party actions are pinned to full commit SHAs and annotated with the audited release version.
- External Cargo tooling uses SHA-pinned `taiki-e/install-action` with `cargo-binstall` fallback. Default CLI versions are pinned to versions exercised by CI; `latest` is opt-in.
- `cargo-test-action` defaults to `cargo nextest run`; `runner: cargo` preserves standard `cargo test` behavior.
- `cargo-bench-action` defaults to `cargo criterion`; `runner: cargo` preserves standard `cargo bench` behavior.
- Boolean input strings are exactly `true` or `false`. Do not accept alternate shell truthy spellings.
- Multi-value and escape-hatch arguments are newline-delimited and never shell-evaluated.
- Shared parsing and validation belongs in `src/_shared/lib.sh`; runner-specific semantics remain in their runner script.
- Changes to any runner grammar require exact argv regression coverage in `tests/test-cargo-command.sh` or `tests/test-tool-runners.sh`.
- Artifact-path behavior requires coverage in `tests/test-artifact-path.sh` across Unix and Windows path forms.
- Every action manifest must pass semantic schema validation in `tests/test-action-yaml.rb` before smoke tests run.
- Public action-surface changes require a matching deterministic eval criterion.
- CI must exercise hosted-runner behavior across Ubuntu, macOS, and Windows plus at least one non-host Rust target.
