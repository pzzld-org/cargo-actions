# Agents Home

Maintain the contents of this file according to the workspace, allowing the root `AGENTS.md` and `CLAUDE.md` policy files to remain stable.

## Workspace

### Purpose

`cargo-actions` provides self-contained, externally consumable composite GitHub Actions for common Cargo commands. Caller workflows own CI orchestration and matrices. Public actions own one Cargo execution.

### Layout

```text
src/
  _shared/cargo-command.sh
  _shared/nextest-command.sh
  _shared/criterion-command.sh
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
  test-cargo-command.sh
  test-tool-runners.sh
  test_action_contracts.py
evals/
  eval_action_surface.py
.github/workflows/
  ci.yml
```

### Contracts

- Do not put matrices or repository-specific post-build behavior inside public Cargo actions.
- Do not use caller-relative nested `uses: ./...` references from public actions.
- Third-party actions are pinned to full commit SHAs.
- External Cargo tooling uses the pinned `taiki-e/install-action` path with `cargo-binstall` fallback rather than defaulting to source compilation.
- `cargo-test-action` defaults to `cargo nextest run`; `runner: cargo` preserves standard `cargo test` behavior.
- `cargo-bench-action` defaults to `cargo criterion`; `runner: cargo` preserves standard `cargo bench` behavior.
- Multi-value and escape-hatch arguments are newline-delimited and never shell-evaluated.
- Changes to any runner grammar require exact argv regression coverage in `tests/test-cargo-command.sh` or `tests/test-tool-runners.sh`.
- Every action manifest must parse through `tests/test-action-yaml.rb` before smoke tests run.
- Changes to the public action surface require a matching eval criterion.
