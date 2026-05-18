# Frozen Phase 0 Baseline

Generated: May 18, 2026

Do not refresh these values after Phase 0 is accepted. Later phases compare against this file and should record before/after movement separately.

## Source Shape

| Metric | Value |
| --- | ---: |
| Source LOC under `scripts/` + `bin/` | 41369 |
| Shell files under `scripts/` | 103 |
| Top-level `scripts/*.sh` | 78 |
| Top-level `scripts/*.py` | 7 |
| `scripts/lib/*.sh` | 25 |
| `scripts/lib/*.py` | 2 |
| `bin/` non-markdown entrypoints | 28 |
| `bin/dhp-*.sh` dispatcher wrappers | 21 |
| Shell test files | 64 |
| Repo-local `logs/` files | 627 |

## Alias Shape

| Metric | Value |
| --- | ---: |
| Aliases in `zsh/aliases.zsh` | 257 |
| Shell functions in `zsh/aliases.zsh` | 12 |
| Daily-core aliases | 22 |
| Compatibility aliases | 42 |
| Convenience aliases | 177 |
| Risky/surprising aliases | 16 |

## Coach Baseline

| File | LOC |
| --- | ---: |
| `scripts/lib/coach_prompts.sh` | 2207 |
| `scripts/lib/coach_metrics.sh` | 1836 |
| `scripts/lib/coach_chat.sh` | 815 |
| `scripts/lib/coach_scoring.sh` | 283 |
| Total | 5141 |

## Product Implementation Baseline

| File | LOC |
| --- | ---: |
| `scripts/cyborg_agent.py` | 5402 |
| `scripts/observer.py` | 3571 |
| `scripts/cyborg_build.py` | 1556 |
| `scripts/cyborg_docs_sync.py` | 1201 |
| Total | 11730 |

## Numeric Exit Gates

- Phase 3: reduce hand-maintained dispatcher wrappers from 21 to one registry-driven entrypoint plus registry data, prompt files, and generated/tiny compatibility shims.
- Phase 4: reduce `coach_prompts.sh` from 2207 LOC to 300 LOC or less; keep `coach_metrics.sh` stable or smaller than 1836 LOC unless an exception is recorded.
- Phase 8: reduce non-wrapper product implementation LOC under root dotfiles from 11730 to approximately 0 after Observer and Cyborg extraction.
