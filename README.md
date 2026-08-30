# cargo-actions

Composable GitHub Actions for Cargo workflows.

The repository separates Cargo execution from CI orchestration. A caller-owned `rust.yml` decides the operating-system matrix, feature matrix, targets, and policy. Each action executes one Cargo operation without inventing a project-specific matrix.

## Actions

| Action | Purpose |
| --- | --- |
| `src/cargo-build-action` | `cargo build`, including package/workspace selection, targets, features, profiles, lock/network modes, custom Cargo config, caching, and optional artifact upload |
| `src/cargo-check-action` | `cargo check` using the same Cargo selection grammar |
| `src/cargo-test-action` | `cargo test` with test-name filtering and safe test-harness argument forwarding |
| `src/cargo-bench-action` | `cargo bench` with benchmark filtering and harness argument forwarding |
| `src/cargo-clippy-action` | `cargo clippy` with the shared grammar, `--no-deps`, lint forwarding, and optional `-D warnings` |
| `src/cargo-doc-action` | `cargo doc` with dependency/private-item controls |
| `src/cargo-fmt-action` | `cargo fmt`, workspace/package selection, and check mode |
| `src/setup-rust-cache` | Standalone sccache plus Rust dependency cache setup |

## Design contract

### `rust.yml` owns orchestration

Do not encode feature or operating-system matrices inside these actions. The caller should describe concrete build configurations:

```yaml
strategy:
  fail-fast: false
  matrix:
    include:
      - id: linux-default
        os: ubuntu-latest
        features: default
      - id: linux-full
        os: ubuntu-latest
        features: full
      - id: windows-default
        os: windows-latest
        features: default
```

Then execute one matrix leg:

```yaml
- name: Build
  uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    workspace: "true"
    all-targets: "true"
    features: ${{ matrix.features }}
    cache-key: build-${{ matrix.id }}
```

This keeps repository policy in the repository and Cargo mechanics in `cargo-actions`.

### One shared Cargo grammar

Build-like actions use `src/_shared/cargo-command.sh`. The script constructs an argv array and invokes Cargo directly. Caller input is never passed through `eval`.

Inputs that may repeat, such as `packages`, `exclude`, `bin`, `example`, `test`, `bench`, `config`, `extra-args`, and harness/lint arguments, use one complete argument or value per line.

Example:

```yaml
with:
  extra-args: |
    --timings
    --config
    net.retry=2
```

A line containing spaces remains one argument. Shell quoting is not re-evaluated.

### Feature behavior

`features` follows Cargo's normal feature syntax, with two convenience values:

- empty or `default`: do not add a feature-selection flag.
- `all`: add `--all-features`.

`all-features` and `no-default-features` remain available as explicit booleans.

### Toolchains and targets

Every compile action installs the requested toolchain. When `target` is non-empty, it is also passed to `actions-rust-lang/setup-rust-toolchain`, so a cross-target build does not assume the target is preinstalled.

`cargo-clippy-action` installs the `clippy` component. `cargo-fmt-action` installs `rustfmt`.

### Cache behavior

Compile actions use the same two cache layers:

1. `mozilla-actions/sccache-action`
2. `Swatinem/rust-cache` with `cache-targets: false`

The Cargo actions repeat those pinned setup steps intentionally. A nested composite action reference such as `uses: ./src/setup-rust-cache` would resolve against the caller workspace when consumed from another repository. Keeping the public actions self-contained avoids that external-consumption failure mode.

Set `cache: "false"` when a job owns caching separately. `cache-key` overrides the derived `<command>-<os>-<toolchain>-<target>` key.

### Escape hatch

The stable interface promotes common Cargo flags to named inputs. `extra-args` covers less-common or newly added Cargo flags without requiring an action release.

Unlike a raw command string, `extra-args` is not shell-evaluated. Supply one argument per line.

## Canonical Rust workflow

A repository can keep a single `.github/workflows/rust.yml`:

```yaml
name: Rust

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  build:
    name: build (${{ matrix.id }})
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - id: linux-default
            os: ubuntu-latest
            features: default
          - id: linux-full
            os: ubuntu-latest
            features: full
          - id: windows-default
            os: windows-latest
            features: default

    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1

      - name: Build
        uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
        with:
          workspace: "true"
          all-targets: "true"
          locked: "true"
          features: ${{ matrix.features }}
          cache-key: build-${{ matrix.id }}

  test:
    name: test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1

      - name: Test
        uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
        with:
          workspace: "true"
          locked: "true"
```

Repository-specific work remains outside the generic Cargo action:

```yaml
- name: Build
  uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    package: shepherd-cli

- name: Stage Shepherd harness carriers
  run: scripts/stage-harness-carriers.sh "$PWD"
```

## Validation

The repository ships three validation layers:

- `tests/test-cargo-command.sh` executes the shared argument grammar against a fake Cargo binary and compares exact argv.
- `tests/test_action_contracts.py` checks public metadata contracts, pinned third-party actions, cross-repository path safety, component/target setup, and forwarding behavior.
- `evals/eval_action_surface.py` scores the intended public surface and requires full coverage.

`.github/workflows/ci.yml` runs those contracts and then smoke-tests build, check, test, clippy, fmt, doc, and bench actions on Linux and Windows against `tests/fixtures/minimal-crate`.

See [QUICKSTART.md](QUICKSTART.md) for copy-paste examples.
