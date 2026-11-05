# Changelog

## Unreleased

### Added

- Shared deterministic Cargo argv builder for build, check, test, bench, clippy, doc, and fmt.
- Shared strict input-validation library for boolean, enum, integer, and mutually exclusive input contracts.
- Cross-platform build-artifact path resolver with Unix, Windows drive, and UNC absolute-path preservation.
- Complete composite action implementations for the Cargo command family.
- Cross-target toolchain setup and optional build artifact publication.
- Safe newline-delimited forwarding for Cargo, test harness, benchmark harness, and Clippy arguments.
- cargo-nextest as the default test runner, with standard `cargo test` retained behind `runner: cargo`.
- cargo-criterion as the default benchmark runner, with standard `cargo bench` retained behind `runner: cargo`.
- Nextest-native profiles, retries, test threads, filtersets, partitions, ignored-test behavior, and no-tests behavior.
- Criterion-native output, plotting, machine-readable message, history, configuration-file, and debug controls.
- `cache-hit` outputs on compile actions and build artifact ID, URL, digest, and resolved-path outputs.
- Build artifact compression, overwrite, hidden-file, and archive controls.
- Semantic action-manifest validation, ShellCheck, artifact-path regression tests, and exact runner argv tests.
- Ubuntu, macOS, and Windows action smoke tests plus an independent `wasm32-unknown-unknown` build lane.

### Changed

- Enhanced Cargo CLI defaults are deterministic: cargo-nextest `0.9.143` and cargo-criterion `1.1.0`. `latest` remains an explicit opt-in.
- `taiki-e/install-action` is pinned to v2.87.4 (`e67fa11c4b9316fa714ddf0abed07a0c3143b95b`) with `cargo-binstall` as the explicit fallback.
- Compile actions now compose one canonical cache primitive through `$/src/setup-rust-cache` instead of duplicating cache implementation details.
- Default dependency-cache keys are shared across compatible Cargo commands and partitioned by OS, toolchain, and target.
- Compile-action dependency caching now defaults to each action's `working-directory`; explicit `cache-workspaces` values remain native rust-cache specifications relative to the job workspace.
- Public action metadata uses block-style mappings and explicit author/output contracts for reviewable API diffs.
- Boolean inputs now accept exactly `true` or `false`; ambiguous shell truthy spellings are rejected.
- Build artifact digests are documented and smoke-tested as the raw 64-character lowercase hexadecimal SHA-256 value returned by `actions/upload-artifact`.

### Fixed

- Absolute `target-dir` values are no longer incorrectly prefixed with `working-directory` when used as the default artifact upload path.
- Nextest `nextest-no-tests` documents and validates the actual `fail`, `warn`, and `pass` values.
- Non-root Cargo projects no longer cause rust-cache metadata discovery to run against the repository root and fall back to an empty lockfile/environment hash.
