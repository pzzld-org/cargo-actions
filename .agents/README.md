# Agents Home

Maintain the contents of this file according to the workspace, allowing the root `AGENTS.md` and `CLAUDE.md` policy files to remain stable.

## Workspace

### Purpose

`cargo-actions` provides self-contained, externally consumable composite GitHub Actions for common Cargo commands. Caller workflows own CI orchestration and matrices. Public actions own one Cargo execution.

### Layout

```text
src/
  _shared/cargo-command.sh
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
  test-cargo-command.sh
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
- Multi-value and escape-hatch arguments are newline-delimited and never shell-evaluated.
- Changes to the shared Cargo grammar require exact argv regression coverage in `tests/test-cargo-command.sh`.
- Changes to the public action surface require a matching eval criterion.
