# Evals

`cargo-actions` is deterministic infrastructure, so the primary eval is deterministic as well.

`eval_action_surface.py` measures whether every public action exposes the intended command-specific surface and whether the shared Cargo runner retains its core composition primitives. The pass threshold is `1.0`.

Run:

```bash
python3 evals/eval_action_surface.py
```

Behavioral correctness is tested separately by `tests/test-cargo-command.sh` and by the GitHub Actions smoke matrix.
