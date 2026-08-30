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

## Test with harness arguments

```yaml
- uses: pzzld-org/cargo-actions/src/cargo-test-action@v0.0.0
  with:
    workspace: "true"
    filter: parser
    test-args: |
      --nocapture
      --test-threads=1
```

This produces the semantic equivalent of:

```text
cargo test --workspace --locked --color always parser -- --nocapture --test-threads=1
```

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

## Additional Cargo arguments

Repeated or escape-hatch values use one complete value per line:

```yaml
with:
  config: |
    net.retry=2
    build.incremental=false
  extra-args: |
    --timings
```

The action does not shell-evaluate these values.

## Disable integrated caching

```yaml
with:
  cache: "false"
```

Use this when the surrounding job has already established its own cache strategy.
