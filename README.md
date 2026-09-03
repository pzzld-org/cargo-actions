# cargo-actions

Composable GitHub Actions for Cargo workflows.

`cargo-actions` separates Cargo execution from CI orchestration. Caller workflows own matrices, event policy, permissions, checkout/ref trust, and repository-specific staging. Each public action owns one Rust operation and exposes a stable step-level contract.

## Actions

| Action | Default execution |
| --- | --- |
| `src/cargo-build-action` | `cargo build`, shared cache, optional artifact upload |
| `src/cargo-check-action` | `cargo check` |
| `src/cargo-test-action` | `cargo nextest run`; `runner: cargo` selects `cargo test` |
| `src/cargo-bench-action` | `cargo criterion`; `runner: cargo` selects `cargo bench` |
| `src/cargo-clippy-action` | `cargo clippy` |
| `src/cargo-doc-action` | `cargo doc` |
| `src/cargo-fmt-action` | `cargo fmt --all --check` |
| `src/setup-rust-cache` | sccache plus Cargo dependency caching |

## Contract

### Orchestration stays with the caller

Do not encode project matrices in these actions. Model concrete CI legs in the caller:

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

Then execute one contract per leg:

```yaml
- name: Build
  uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    workspace: 'true'
    all-targets: 'true'
    features: ${{ matrix.features }}
```

Repository-specific behavior remains outside the action:

```yaml
- name: Build
  uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    package: shepherd-cli

- name: Stage Shepherd harness carriers
  run: scripts/stage-harness-carriers.sh "$PWD"
```

### Pin the action ref deliberately

For security-sensitive consumers, pin `pzzld-org/cargo-actions` to an immutable commit SHA. Version tags are appropriate when the caller intentionally follows a maintained release line. The third-party actions used inside this repository are pinned to full commit SHAs and annotated with their audited release versions.

### Inputs are strings

GitHub composite-action inputs are strings. Boolean inputs therefore accept exactly `true` or `false`. Values such as `yes`, `1`, or `on` are rejected instead of being interpreted differently by a shell step and an Actions expression.

Repeated values and escape-hatch arguments are newline-delimited. Each non-empty line is one complete argv element:

```yaml
with:
  extra-args: |
    --timings
    --config
    net.retry=2
```

A line containing spaces remains one argument. Caller input is never shell-evaluated.

### Shared Cargo grammar

`src/_shared/cargo-command.sh` implements the Cargo-native grammar. Nextest and cargo-criterion use dedicated argv builders because their interfaces are similar to Cargo but not identical. `src/_shared/lib.sh` owns shared parsing and validation.

The public compile actions consistently expose package/workspace selection, target selection, features, target triples, profiles, lock/network modes, output controls, Cargo configuration, caching, and newline-delimited escape hatches where the underlying runner supports them. Unsupported runner/input combinations fail with an explicit error instead of silently dropping flags.

### Feature selection

`features` follows Cargo feature syntax with two convenience values:

- empty or `default`: preserve normal Cargo defaults;
- `all`: map to `--all-features`.

`all-features` and `no-default-features` remain available as explicit booleans.

## Test runner

`cargo-test-action` defaults to cargo-nextest `0.9.143`, the version exercised by this repository's smoke matrix. Override `nextest-version` deliberately, including `latest` when following upstream latest is desired.

Installation uses SHA-pinned `taiki-e/install-action`. The installer can consume nextest's published binaries directly and has `cargo-binstall` configured as its explicit fallback.

Nextest-specific inputs include:

- `nextest-profile`
- `nextest-retries`
- `nextest-test-threads`
- `nextest-filterset`
- `nextest-partition`
- `nextest-run-ignored` (`default`, `only`, `all`)
- `nextest-no-tests` (`fail`, `warn`, `pass`)

`jobs` maps to nextest `--build-jobs`; `profile` maps to `--cargo-profile`. `runner: cargo` restores standard `cargo test` semantics.

```yaml
- name: Test
  uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
  with:
    workspace: 'true'
    nextest-profile: ci
    nextest-retries: '2'
```

## Benchmark runner

`cargo-bench-action` defaults to cargo-criterion `1.1.0`, installed through SHA-pinned `taiki-e/install-action` with `cargo-binstall` fallback. The project still owns its benchmark definitions and Criterion dependencies.

Criterion-specific inputs include:

- `criterion-manifest-path`
- `criterion-output-format` (`criterion`, `quiet`, `verbose`, `bencher`)
- `criterion-plotting-backend` (`gnuplot`, `plotters`, `disabled`)
- `criterion-message-format` (`json`, `openmetrics`)
- `criterion-history-id`
- `criterion-history-description`
- `criterion-debug`

cargo-criterion uses Cargo's benchmark profile by default. Select `runner: cargo` when a workflow requires a custom Cargo profile, Cargo `--config`, `--ignore-rust-version`, or Cargo-native message formatting.

```yaml
- name: Bench
  uses: pzzld-org/cargo-actions/src/cargo-bench-action@v0.0.0
  with:
    no-run: 'true'
    criterion-plotting-backend: plotters
```

## Toolchains and targets

Every compile action installs the requested Rust toolchain. A non-empty `target` is also installed before Cargo runs. Clippy installs the `clippy` component and format installs `rustfmt`.

```yaml
- name: Build WASM
  uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    package: my-component
    target: wasm32-wasip2
```

The repository CI independently smoke-tests `wasm32-unknown-unknown` so target installation is part of the action contract, not an assumption about hosted-runner state.

## Cache model

Compile actions compose `src/setup-rust-cache` through GitHub's same-repository `$/src/setup-rust-cache` reference. The reference resolves against the repository and revision of the running action, so consumers do not need to check out `cargo-actions` separately and the cache implementation cannot accidentally resolve against the caller workspace.

The cache primitive uses:

1. `mozilla-actions/sccache-action` for compiler caching;
2. `Swatinem/rust-cache` with `cache-targets: false` for dependency caching.

Default dependency-cache keys are shared across compatible Cargo operations and derive from operating system, toolchain, and target. Set `cache-key` when a caller needs an additional partition. Every compile action exposes `cache-hit` for downstream composition.

`$/...` same-repository action references are supported on GitHub.com. GitHub Enterprise Server does not currently support this reference form; GHES consumers need a compatibility release that uses a different composition strategy.

## Build artifacts

`cargo-build-action` can upload outputs through pinned `actions/upload-artifact`.

```yaml
- name: Build
  id: build
  uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    release: 'true'
    artifact: 'true'
    artifact-name: binaries
    artifact-path: target/release/my-app
    artifact-retention-days: '7'
    artifact-compression-level: '0'

- name: Record artifact digest
  run: echo '${{ steps.build.outputs.artifact-digest }}'
```

Artifact controls expose `if-no-files-found`, retention, compression, overwrite, hidden-file inclusion, and archive behavior. Relative `artifact-path` and `target-dir` values resolve from `working-directory`; Unix absolute paths, Windows drive paths, and UNC paths are preserved.

Build outputs:

- `cache-hit`
- `artifact-id`
- `artifact-url`
- `artifact-digest`
- `artifact-path`

## CI example

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
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Build
        uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
        with:
          workspace: 'true'
          all-targets: 'true'
          features: ${{ matrix.features }}

  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Nextest
        uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
        with:
          workspace: 'true'
          nextest-profile: ci
```

## Verification

The repository gates changes through deterministic checks before hosted-runner smoke tests:

- semantic action-manifest schema validation;
- `bash -n` and ShellCheck for shared/test shell code;
- exact argv regression tests for Cargo, nextest, and cargo-criterion;
- cross-platform artifact-path tests;
- metadata and supply-chain contract tests;
- deterministic public-surface eval with a 1.0 pass threshold;
- Ubuntu, macOS, and Windows smoke jobs;
- artifact upload/output verification;
- independent WASM target installation/build verification.

See [QUICKSTART.md](QUICKSTART.md) for focused examples.
