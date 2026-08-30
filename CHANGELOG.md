# Changelog

## Unreleased

### Added

- Shared deterministic Cargo argv builder for build, check, test, bench, clippy, doc, and fmt.
- Complete composite action implementations for the Cargo command family.
- Cross-target toolchain setup, shared sccache/dependency caching, and optional build artifact publication.
- Safe newline-delimited forwarding for Cargo, test harness, benchmark harness, and Clippy arguments.
- `cargo-nextest` as the default test runner, with standard `cargo test` retained behind `runner: cargo`.
- `cargo-criterion` as the default benchmark runner, with standard `cargo bench` retained behind `runner: cargo`.
- SHA-pinned `taiki-e/install-action` integration for enhanced Cargo tools with `cargo-binstall` as the explicit fallback installation path.
- Nextest-native profiles, retries, test threads, filtersets, partitions, ignored-test behavior, and no-tests behavior.
- Criterion-native output, plotting, machine-readable message, history, configuration-file, and debug controls.
- Exact argv contract coverage for the Cargo, nextest, and Criterion runners.
- Linux/Windows smoke workflow, metadata contract tests, and deterministic action-surface eval.
- Canonical `rust.yml` composition guidance and quickstart documentation.
