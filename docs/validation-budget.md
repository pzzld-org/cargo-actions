# Validation and budget evidence

Observed 2026-10-04 for the local candidate based on
`89182d8d4e5dfd62ce483d2b682c4e3fd76092e2`.

## Local evidence

`python3 tests/test_cache_policy.py`: eight test methods pass, including ten
restore-only event/ref cases, invalid boolean/empty key failures, shell-literal
input, configurable default branch, compiler opt-out, and parsed action wiring.
The existing grammar, action metadata, artifact paths, manifest schema,
ShellCheck and actionlint checks pass. `evals/eval_action_surface.py` scores
88/88. Real fixture Cargo test (including its doctest phase), Clippy and fmt pass.
No generated-template, Axiom, Windows or Linux runtime was tested locally.

`python3 evals/measure_local_reuse.py` copies the dependency-free fixture into a
temporary directory and requires this exact sequence of compiler-artifact records:

| Case | Compiled | Fresh | Local seconds (single sample) |
| --- | ---: | ---: | ---: |
| Cold library build | 1 | 0 | 0.4483 |
| Identical repeat | 0 | 1 | 0.1423 |
| Feature `full` selected | 1 | 0 | 0.1283 |
| Same feature repeated | 0 | 1 | 0.0997 |
| Release profile selected | 1 | 0 | 0.1294 |
| Same profile repeated | 0 | 1 | 0.1012 |

Host: macOS arm64, rustc 1.99.0 (b940084d7 2026-09-28). Timing is a tiny local
sample with process-start variance; only freshness/invalidation is a test
assertion. No hosted speedup, remote restore, sccache hit or dollar savings is
inferred from this sample.

## Existing hosted evidence, read only

[Completed run 33701580352](https://github.com/pzzld-org/cargo-actions/actions/runs/33701580352)
was a **pre-change** push run of baseline `89182d8` on 2026-09-03. This task only
read its logs and job timestamps; it did not run, retry or dispatch Actions.

| Job | Assigned runner seconds | Dependency evidence | sccache final snapshot hits/misses |
| --- | ---: | --- | ---: |
| Contracts | 15 | Not used | Not used |
| Windows smoke | 81 | Partial restore succeeded; exact cache-hit false | 1 / 3 |
| macOS smoke | 82 | No dependency cache found; exact cache-hit false | 1 / 3 |
| Ubuntu smoke | 29 | Partial restore succeeded; exact cache-hit false | 2 / 2 |
| Cross target | 16 | Disabled | Not used |

Sum: **223 seconds / 3.7167 runner-minutes**, without billing multipliers or
rounding. Repeated sccache post output is one snapshot per job, not additional
hits. The four reported hits do not establish cross-run reuse rather than
same-job reuse. There is no matched cold/warm hosted pair. The new default preserves compiler-cache reads using sccache GHA READ_ONLY on
PR/dev events; candidate runtime effect remains unmeasured. Retained target directories between steps and
local qualification remain the primary avoidable-compilation controls.

## Proposed hosted budget, not activated

| Event/cohort | Jobs | Budget status |
| --- | ---: | --- |
| Current repository push | 5 | Historical measured sample above; current timeout sum 65 runner-minutes |
| Current PR | 5 | Same source topology; no PR runtime measured here |
| Ordinary development push after explicit caller-policy activation | 0 | Local validation only; proposal, no trigger changed |
| Final/release-critical action qualification | 5 | Preserve contracts + 3 OS smoke jobs + cross-target coverage; 65-minute summed timeout ceiling, not predicted usage |

A push associated with an open PR can create both existing cohorts. Avoiding that
requires a separately approved trigger policy; concurrency by ref does not dedupe
`refs/heads/...` against `refs/pull/.../merge`. No numeric savings forecast is
supported by the current evidence. A larger Rust consumer must supply its own
native coverage matrix and measured budget; this fixture does not size Axiom.

All dependency implementations remain SHA-pinned. `ci.yml` still triggers every
push, so this candidate must remain local until publication/activation is approved.
