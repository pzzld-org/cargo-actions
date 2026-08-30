# Quickstart

## Build a workspace

```yaml
- name: Checkout
  uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1

- name: Build
  uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    workspace: "true"
    all-targets: "true"
    locked: "true"
```

## Test with nextest (default)

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
  with:
    workspace: "true"
    nextest-profile: ci
    nextest-retries: "2"
```

The action installs `cargo-nextest` through the pinned `taiki-e/install-action`, with `cargo-binstall` configured as its fallback installation path.

Use nextest-native filtersets when useful:

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
  with:
    nextest-filterset: |
      package(core) & not test(slow)
      package(cli)
    nextest-test-threads: num-cpus
```

Test-name filters and libtest-compatible arguments after `--` remain available:

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
  with:
    filter: parser
    test-args: |
      --nocapture
      --exact
```

To use standard Cargo instead:

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
  with:
    runner: cargo
    workspace: "true"
```

## Benchmark with Criterion (default)

Projects define their Criterion-compatible benchmark targets in `Cargo.toml`; the action installs and runs `cargo-criterion` by default.

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-bench-action@v0.0.0
  with:
    workspace: "true"
    criterion-output-format: criterion
    criterion-plotting-backend: plotters
```

Compile without executing benchmarks:

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-bench-action@v0.0.0
  with:
    no-run: "true"
```

Use standard `cargo bench` when you need Cargo-specific benchmark behavior such as a custom Cargo profile or raw Cargo configuration overrides:

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-bench-action@v0.0.0
  with:
    runner: cargo
    profile: ci-bench
```

## Build a feature matrix

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
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1

      - uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
        with:
          workspace: "true"
          all-targets: "true"
          features: ${{ matrix.features }}
          cache-key: build-${{ matrix.id }}
```

## Cross-compile

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-build-action@v0.0.0
  with:
    target: wasm32-wasip2
    package: my-component
```

The target is installed with the requested Rust toolchain before Cargo runs.

## Clippy

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-clippy-action@v0.0.0
  with:
    workspace: "true"
    all-targets: "true"
    all-features: "true"
    deny-warnings: "true"
```

## Format

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-fmt-action@v0.0.0
  with:
    workspace: "true"
    check: "true"
```

## Additional runner arguments

Repeated or escape-hatch values use one complete value per line:

```yaml
with:
  extra-args: |
    --timings
```

Cargo-native actions can also use configuration overrides:

```yaml
with:
  config: |
    net.retry=2
    build.incremental=false
```

No runner shell-evaluates these values.

## Disable integrated caching

```yaml
with:
  cache: "false"
```

Use this when the surrounding job has already established its own cache strategy.
