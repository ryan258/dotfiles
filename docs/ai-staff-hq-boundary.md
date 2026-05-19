# AI Staff HQ Boundary

AI Staff HQ is an optional product dependency for dispatcher and Morphling
workflows. Root dotfiles does not require it for the daily loop.

Default location:

```text
~/dotfiles/ai-staff-hq
```

Supported override:

```bash
export AI_STAFF_DIR="$HOME/Projects/ai-staff-hq"
```

Root dotfiles owns:

- dispatcher wrappers under `bin/dhp-*.sh`
- `bin/dhp-shared.sh`
- `bin/dhp-swarm.py`
- `bin/morphling.sh`
- graceful missing-product messages

AI Staff HQ owns:

- specialist definitions
- LangGraph / Python orchestration
- `tools/activate.py`
- its own tests, dependencies, UI rules, and documentation

Daily commands such as `startday`, `status`, and `goodevening` must keep
working when `AI_STAFF_DIR` is missing. Dispatcher commands may exit with a
short setup message instead of a stack trace.

## Tests

- `tests/test_ai_staff_boundary.sh` — covers the `AI_STAFF_DIR` sibling-checkout override.
- `tests/test_optional_product_degradation.sh` — covers missing `AI_STAFF_DIR` for the bash dispatcher path (the canonical entrypoint); also asserts no Python stack trace surfaces.
- `tests/test_morphling_wrapper.sh` — covers `AI_STAFF_DIR` override for `bin/morphling.sh`.
