# Quickstart

## Build a workspace

```yaml
- name: Checkout
  uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

- name: Build
  uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    workspace: 'true'
    all-targets: 'true'
    locked: 'true'
```

All boolean inputs are exact strings: `true` or `false`.

## Test with nextest

Nextest is the default runner. The tested default version is `0.9.143`.

```yaml
- name: Test
  uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
  with:
    workspace: 'true'
    nextest-profile: ci
    nextest-retries: '2'
    nextest-no-tests: fail
```

The action uses pinned `taiki-e/install-action` and explicitly enables `cargo-binstall` fallback. To opt into upstream latest rather than the tested version:

```yaml
with:
  nextest-version: latest
```

Filtersets remain separate from the optional positional test-name filter:

```yaml
with:
  nextest-filterset: |
    package(core) & not test(slow)
    package(cli)
  nextest-test-threads: num-cpus
```

Use standard Cargo when its test runner semantics are required:

```yaml
with:
  runner: cargo
  test-args: |
    --nocapture
    --test-threads=1
```

## Benchmark with cargo-criterion

cargo-criterion is the default benchmark runner. The tested default version is `1.1.0`.

```yaml
- name: Bench
  uses: pzzld-org/cargo-actions/src/cargo-bench-action@v0.0.0
  with:
    no-run: 'true'
    criterion-output-format: criterion
    criterion-plotting-backend: plotters
```

Use standard `cargo bench` when you need Cargo-only controls:

```yaml
with:
  runner: cargo
  profile: ci-bench
```

## Upload build artifacts

```yaml
- name: Build
  id: build
  uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    release: 'true'
    artifact: 'true'
    artifact-path: target/release/my-app
    artifact-retention-days: '3'
    artifact-compression-level: '0'

- name: Use artifact metadata
  env:
    ARTIFACT_ID: ${{ steps.build.outputs.artifact-id }}
    ARTIFACT_DIGEST: ${{ steps.build.outputs.artifact-digest }}
  run: printf '%s %s\n' "$ARTIFACT_ID" "$ARTIFACT_DIGEST"
```

Relative artifact paths resolve from `working-directory`. Absolute Unix, Windows drive, and UNC paths are preserved.

## Build a matrix

```yaml
jobs:
  build:
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
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
        with:
          workspace: 'true'
          all-targets: 'true'
          features: ${{ matrix.features }}
```

The caller owns the matrix. The Cargo action only executes the selected leg.

## Cross-compile

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    package: my-component
    target: wasm32-wasip2
```

The action installs the requested target before Cargo runs.

## Clippy

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-clippy-action@v0.0.0
  with:
    workspace: 'true'
    all-targets: 'true'
    all-features: 'true'
    deny-warnings: 'true'
```

## Format

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-fmt-action@v0.0.0
  with:
    workspace: 'true'
    check: 'true'
```

## Repeated and escape-hatch arguments

One non-empty line equals one argv element:

```yaml
with:
  extra-args: |
    --timings
    --config
    net.retry=2
```

No action shell-evaluates these values.

## Cache behavior

Integrated caching is enabled by default and shared across compatible Cargo commands for the same OS, toolchain, and target. Disable it when the surrounding job owns caching:

```yaml
with:
  cache: 'false'
```

Compile actions expose `cache-hit` for downstream steps.

The public compile actions use GitHub's `$/src/setup-rust-cache` same-repository reference. This composition model targets GitHub.com; GitHub Enterprise Server does not currently support `$/...` action references.
