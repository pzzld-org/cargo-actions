# cargo-actions

Composable GitHub Actions for Cargo workflows.

The repository separates Cargo execution from CI orchestration. A caller-owned `rust.yml` decides the operating-system matrix, feature matrix, targets, and policy. Each action executes one Cargo operation without inventing a project-specific matrix.

## Actions

| Action | Purpose |
| --- | --- |
| `src/cargo-build-action` | `cargo build`, including package/workspace selection, targets, features, profiles, lock/network modes, custom Cargo config, caching, and optional artifact upload |
| `src/cargo-check-action` | `cargo check` using the same Cargo selection grammar |
| `src/cargo-test-action` | `cargo nextest run` by default, with `cargo test` as an explicit fallback |
| `src/cargo-bench-action` | `cargo criterion` by default, with `cargo bench` as an explicit fallback |
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

### Runner defaults

`cargo-test-action` defaults to `runner: nextest`. `cargo-bench-action` defaults to `runner: criterion`.

Both tool runners are installed with the SHA-pinned `taiki-e/install-action`. Its fallback is explicitly set to `cargo-binstall`, avoiding source recompilation when a binary installation path is available.

Use the Cargo fallback explicitly when a project requires behavior not supported by the enhanced runner:

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
  with:
    runner: cargo

- uses: pzzld-org/cargo-actions/src/cargo-bench-action@v0.0.0
  with:
    runner: cargo
```

### Nextest

The default test runner preserves the package, workspace, target, feature, target-triple, lock/network, filter, `--no-run`, and trailing-argument contracts from the Cargo test action.

It also exposes nextest-native controls:

- `nextest-profile`
- `nextest-retries`
- `nextest-test-threads`
- `nextest-filterset`
- `nextest-partition`
- `nextest-run-ignored`
- `nextest-no-tests`

`jobs` maps to nextest's build parallelism (`--build-jobs`). `profile` maps to `--cargo-profile`.

### Criterion

The default benchmark runner uses `cargo-criterion`, not a renamed `cargo bench` invocation. The project must still define compatible benchmark targets in its own `Cargo.toml`.

Criterion-native controls include:

- `criterion-manifest-path`
- `criterion-output-format`
- `criterion-plotting-backend`
- `criterion-message-format`
- `criterion-history-id`
- `criterion-history-description`
- `criterion-debug`

`cargo-criterion` uses the benchmark profile by default. If a workflow needs a custom Cargo profile, `--config`, `--ignore-rust-version`, or Cargo-specific message formatting, use `runner: cargo`.

### Shared command grammars

Build-like actions use `src/_shared/cargo-command.sh`. Nextest and Criterion have dedicated deterministic argv builders in `src/_shared/nextest-command.sh` and `src/_shared/criterion-command.sh` because their command-line grammars differ from Cargo in material ways.

All scripts construct argv arrays and invoke Cargo directly. Caller input is never passed through `eval`.

Inputs that may repeat, such as `packages`, `exclude`, `bin`, `example`, `test`, `bench`, `config`, `extra-args`, filtersets, and harness/lint arguments, use one complete argument or value per line.

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

Set `cache: "false"` when a job owns caching separately. Test and bench cache keys include the selected runner so Cargo, nextest, and Criterion lanes do not collide.

### Escape hatch

The stable interface promotes common flags to named inputs. `extra-args` covers less-common or newly added runner flags without requiring an action release.

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
    name: nextest
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1

      - name: Test
        uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
        with:
          workspace: "true"
          locked: "true"
          nextest-profile: ci

  bench:
    name: criterion
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1

      - name: Bench
        uses: pzzld-org/cargo-actions/src/cargo-bench-action@v0.0.0
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

- `tests/test-cargo-command.sh` executes the shared Cargo grammar against a fake Cargo binary and compares exact argv.
- `tests/test-tool-runners.sh` does the same for nextest and Criterion.
- `tests/test_action_contracts.py` checks public metadata contracts, runner defaults, pinned third-party actions, cargo-binstall fallback, cross-repository path safety, component/target setup, and forwarding behavior.
- `evals/eval_action_surface.py` scores the intended public surface and requires full coverage.

`.github/workflows/ci.yml` runs those contracts and then smoke-tests the action family on Linux and Windows. The smoke lane exercises the default nextest and Criterion paths plus the explicit Cargo fallbacks.

See [QUICKSTART.md](QUICKSTART.md) for copy-paste examples.
