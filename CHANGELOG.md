# Changelog

## Unreleased

### Added

- Shared deterministic Cargo argv builder for build, check, test, bench, clippy, doc, and fmt.
- Complete composite action implementations for the Cargo command family.
- Cross-target toolchain setup, shared sccache/dependency caching, and optional build artifact publication.
- Safe newline-delimited forwarding for Cargo, test harness, benchmark harness, and Clippy arguments.
- Linux/Windows smoke workflow, exact argv contract tests, metadata contract tests, and deterministic action-surface eval.
- Canonical `rust.yml` composition guidance and quickstart documentation.
