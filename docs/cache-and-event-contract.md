# Cache and event contract (candidate, not activated)

## Boundary

Composite actions execute one Cargo operation inside the caller's job. They do
not checkout code, choose events, grant permissions, create branches, publish, or
invent matrices. A reusable workflow, if a caller needs one, owns jobs/runners,
checkout, secrets, concurrency, qualification scope and release approval. There is
no new reusable workflow to activate in this change.

Prefer one local qualification command and reuse its target directory. In a final
hosted qualification, run tests without a preceding redundant `cargo build` when
those tests compile the required targets. Keep fmt, Clippy, doctests and explicit
platform/feature/target requirements; `nextest` does not replace doctests. Run
`cargo test --doc` separately when using nextest. Benchmarks remain explicit
release/performance work, not an automatic PR matrix leg. Group compatible steps
in one job; matrix only the configurations that establish distinct coverage.

## Public cache API

All six compile actions retain `toolchain`, `working-directory`, `target`,
`features`, `all-features`, `no-default-features`, `profile`, `release`,
`cache`, `cache-key`, `cache-workspaces`, and `cache-hit`.

| Compile action input | Standalone cache input | Default | Meaning |
| --- | --- | --- | --- |
| `cache-save-if` | `save-if` | `false` | Request writes; accepted only for `push` to `refs/heads/<event.repository.default_branch>` |
| `cache-sccache` | `sccache` | `true` | Configure pinned sccache 0.17.0 with READ_ONLY by default, READ_WRITE only when permitted |
| `cache-key` | `key` | Derived / required | Shared dependency namespace; not a compiled-artifact compatibility claim |
| `cache-workspaces` | `workspaces` | Working directory / `.` | Cargo workspace specifications relative to the job workspace |

Outputs: `cache-hit` forwards rust-cache's exact-match indicator; `false` does
not distinguish a partial restore from a miss. `cache-write-enabled` (standalone
`write-enabled`) reports policy permission, not successful save. `sccache-enabled`
reports configuration, not hits. `sccache-mode` reports `READ_ONLY`, `READ_WRITE` or `disabled`. Outputs are empty when `cache: 'false'` skips
setup. Observe rust-cache restore logs and sccache post-step statistics to prove
remote behavior; a green job or an enabled cache is not evidence of savings.

Cache setup is job-wide. Call it once; use `cache: 'false'` on subsequent actions.
It owns only caching it configures. Prior wrappers, running sccache daemons, caller
steps, or modified workflows are outside its policy boundary. Use fresh isolated
runners and do not preconfigure a writable compiler backend in a restore-only job.

## Compatibility

| Layer | Compatibility boundary |
| --- | --- |
| Dependency downloads | Existing shared key covers OS/toolchain/target. Upstream rust-cache also hashes actual rustc release/host/hash, Cargo manifests/locks, configured Rust environment and root toolchain/Cargo config. `cache-targets: false` and `cache-bin: false` exclude compiled target artifacts and installed executables. Features/profiles need no extra partition for downloaded source archives. |
| Same-job Cargo target directory | Cargo fingerprints compiler/configuration/features; profiles have distinct artifact directories. Keep target, toolchain, flags and feature intent explicit on every step. A changed configuration can still recompile. |
| Pinned sccache | Compiler invocation/source hashing governs compatibility, including feature cfg and profile flags; the shared dependency key does not control sccache. Incremental Rust compilation, linking and some crate types limit reuse. Pin toolchains and test required configurations. |

Do not add target-directory archive restore keys that bridge toolchains, targets,
features, profiles or trust domains. This change deliberately does not cache
`target/` across jobs. `--config`/custom compiler wrappers/build-script environment
can affect compilation; a dependency cache hit never certifies compiled outputs.

## Trust and event policy

The default is dependency restore only. Same-repository and fork PRs, tags,
release, workflow_dispatch, workflow_run and pull_request_target cannot opt into
writes through this action. Only an opted-in default-branch push can write. The
pinned sccache GHA backend uses `SCCACHE_GHA_RW_MODE=READ_ONLY` for restore-only
jobs and `READ_WRITE` for opted-in default-branch pushes. `cache-sccache: 'false'`
skips compiler-cache setup. No repository secrets are required.

Caller workflows should set `permissions: {contents: read}`, checkout with
`persist-credentials: false`, and use `cache-mode: read` for untrusted jobs on
runners supporting that GitHub.com setting. Actions inputs are not a security
boundary against a contributor who can replace the workflow. Never execute PR
code under pull_request_target or with release credentials. Caches are not secret
storage: fork PRs can read permitted base-branch caches. Use a fresh, separate
release job and explicit credentials only after qualification of the exact SHA.

| Event | Proposed caller behavior (not installed) |
| --- | --- |
| Ordinary development push | Local tests; no hosted compile fanout |
| PR opened/synchronize | Local validation; final hosted qualification only by explicit approved caller policy |
| Final qualification | One cohort at the exact SHA, retaining required platform/feature/target/doctest checks |
| Release/bump | Bumper dry-run plan first; later activation must enforce expected refs and qualification SHA before mutations |

For read-only checks, a caller can cancel obsolete runs with a group containing
workflow identity and PR number or ref. For future branch/release writes, serialize
per repository/transition target and use `cancel-in-progress: false`. Concurrency
does not guarantee ordering or an atomic compare-and-swap; re-read refs and check
idempotency/state immediately before any future write. Current bumper planning
cannot create, merge, bump, tag or publish anything.

## Dependency and rollout policy

External action implementations remain pinned to full audited commit SHAs with
version comments. The sccache executable is now pinned to `v0.17.0`; it previously
resolved latest despite its action SHA pin. Cargo/nextest/Criterion existing pins
and coverage remain intact. Publish a reviewed action commit and pin consumers to
that full SHA only after activation approval. Existing `$/src/setup-rust-cache`
composition is retained; the baseline targets GitHub.com, not GHES. Local tests
cannot establish runner support for that baseline syntax.

No trigger change or hosted run is part of this candidate. The repository's current
CI triggers every push and PR, so source stays locally committed. Caller adoption,
cache writer selection, final-check trigger changes, and any branch/release executor
require separate activation decisions.

## Sources checked 2026-10-04

- [GitHub action versus workflow reuse](https://docs.github.com/en/actions/concepts/workflows-and-actions/avoiding-duplication)
- [GitHub cache scope and fork access](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)
- [GitHub concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)
- [Cargo profiles](https://doc.rust-lang.org/cargo/reference/profiles.html)
- [Pinned rust-cache interface](https://github.com/Swatinem/rust-cache/blob/6323deb102c322ba6fcbdcafc7e3dddab59af2b6/action.yml)
- [sccache 0.17 GHA read-only mode](https://github.com/mozilla/sccache/blob/v0.17.0/docs/GHA.md)
- [sccache 0.17 configuration](https://github.com/mozilla/sccache/blob/v0.17.0/docs/Configuration.md)
- [sccache Rust limits](https://github.com/mozilla/sccache/blob/v0.17.0/docs/Rust.md)
