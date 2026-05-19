# Script Inventory

Generated: May 18, 2026

## Summary

- Shell files under `scripts/`: 105
- Top-level `scripts/*.sh`: 78
- Top-level `scripts/*.py`: 2
- Sourced shell libraries under `scripts/lib/`: 27
- Python modules under `scripts/lib/`: 2
- `bin/` non-markdown entrypoints: 28

## Classification Summary

- Daily-core scripts: 26
- Support libraries: 35
- Compatibility wrappers: 24
- Sibling-product candidates: 2
- Support utilities: 50

## Dispatcher Registry

- Registry file: `config/dhp-dispatchers.tsv`
- Registry entries: 17
- Registry-backed swarm dispatchers: 10
- Custom/specialized dispatcher entries: 7
- Prompt files under `bin/prompts/`: 10
- Tiny registry shims under `bin/`: 10

## Class Definitions

- **daily-core**: Directly supports daily loop, data, health, focus, or context routines.
- **support-library**: Sourced or imported helper code used by runnable commands.
- **compatibility-wrapper**: Preserve command surface while implementation may move or consolidate.
- **sibling-product-candidate**: Candidate for Cyborg, observer, blog, or other product boundary extraction.
- **support-utility**: General maintenance or convenience command retained in root dotfiles.

Daily-core includes commands that directly or indirectly support the daily loop. Phase 8 extraction should preserve the narrower daily command surface from the roadmap even when broader helper commands are classified here.

## Script Classification

| Path | Class |
| --- | --- |
| `bin/coach-chat.py` | support-library |
| `bin/cyborg` | compatibility-wrapper |
| `bin/cyborg-sync` | compatibility-wrapper |
| `bin/dhp-brand.sh` | compatibility-wrapper |
| `bin/dhp-chain.sh` | compatibility-wrapper |
| `bin/dhp-coach.sh` | compatibility-wrapper |
| `bin/dhp-content.sh` | compatibility-wrapper |
| `bin/dhp-context.sh` | support-library |
| `bin/dhp-copy.sh` | compatibility-wrapper |
| `bin/dhp-creative.sh` | compatibility-wrapper |
| `bin/dhp-finance.sh` | compatibility-wrapper |
| `bin/dhp-lib.sh` | support-library |
| `bin/dhp-market.sh` | compatibility-wrapper |
| `bin/dhp-memory-search.sh` | compatibility-wrapper |
| `bin/dhp-memory.sh` | compatibility-wrapper |
| `bin/dhp-morphling.sh` | compatibility-wrapper |
| `bin/dhp-narrative.sh` | compatibility-wrapper |
| `bin/dhp-project.sh` | compatibility-wrapper |
| `bin/dhp-research.sh` | compatibility-wrapper |
| `bin/dhp-shared.sh` | support-library |
| `bin/dhp-stoic.sh` | compatibility-wrapper |
| `bin/dhp-strategy.sh` | compatibility-wrapper |
| `bin/dhp-swarm.py` | support-library |
| `bin/dhp-tech.sh` | compatibility-wrapper |
| `bin/dhp-utils.sh` | support-library |
| `bin/dispatch.sh` | compatibility-wrapper |
| `bin/morphling.sh` | compatibility-wrapper |
| `bin/swipe.sh` | support-utility |
| `scripts/ai_suggest.sh` | support-utility |
| `scripts/app_launcher.sh` | support-utility |
| `scripts/archive_manager.sh` | support-utility |
| `scripts/backup_data.sh` | support-utility |
| `scripts/backup_project.sh` | support-utility |
| `scripts/bash_graph.py` | support-utility |
| `scripts/bash_graph.sh` | support-utility |
| `scripts/bash_intel.sh` | support-utility |
| `scripts/battery_check.sh` | support-utility |
| `scripts/blog.sh` | sibling-product-candidate |
| `scripts/blog_recent_content.sh` | sibling-product-candidate |
| `scripts/cheatsheet.sh` | support-utility |
| `scripts/clipboard_manager.sh` | support-utility |
| `scripts/context.sh` | support-utility |
| `scripts/correlate.sh` | daily-core |
| `scripts/cyborg_scoped_site_check.sh` | compatibility-wrapper |
| `scripts/data_validate.sh` | support-utility |
| `scripts/dev_shortcuts.sh` | support-utility |
| `scripts/done.sh` | daily-core |
| `scripts/dotfiles_check.sh` | support-utility |
| `scripts/drive.sh` | daily-core |
| `scripts/dump.sh` | support-utility |
| `scripts/duplicate_finder.sh` | support-utility |
| `scripts/file_organizer.sh` | support-utility |
| `scripts/findbig.sh` | support-utility |
| `scripts/findtext.sh` | support-utility |
| `scripts/fitbit_import.sh` | daily-core |
| `scripts/fitbit_metrics.py` | support-utility |
| `scripts/fitbit_sync.sh` | daily-core |
| `scripts/focus.sh` | daily-core |
| `scripts/g.sh` | support-utility |
| `scripts/gcal.sh` | daily-core |
| `scripts/generate_report.sh` | daily-core |
| `scripts/gh-projects.sh` | daily-core |
| `scripts/github_helper.sh` | support-utility |
| `scripts/gitnexus.sh` | compatibility-wrapper |
| `scripts/goodevening.sh` | daily-core |
| `scripts/grab_all_text.sh` | support-utility |
| `scripts/greeting.sh` | support-utility |
| `scripts/health.sh` | daily-core |
| `scripts/howto.sh` | support-utility |
| `scripts/idea.sh` | daily-core |
| `scripts/insight.sh` | daily-core |
| `scripts/inventory.sh` | support-utility |
| `scripts/journal.sh` | daily-core |
| `scripts/lib/blog_common.sh` | support-library |
| `scripts/lib/blog_gen.sh` | support-library |
| `scripts/lib/blog_lifecycle.sh` | support-library |
| `scripts/lib/blog_ops.sh` | support-library |
| `scripts/lib/blog_validate.py` | support-library |
| `scripts/lib/coach_brief.sh` | support-library |
| `scripts/lib/coach_chat.sh` | support-library |
| `scripts/lib/coach_metrics.sh` | support-library |
| `scripts/lib/coach_ops.sh` | support-library |
| `scripts/lib/coach_prebrief.sh` | support-library |
| `scripts/lib/coach_prompts.sh` | support-library |
| `scripts/lib/coach_scoring.sh` | support-library |
| `scripts/lib/coaching.sh` | support-library |
| `scripts/lib/common.sh` | support-library |
| `scripts/lib/config.sh` | support-library |
| `scripts/lib/context_capture.sh` | support-library |
| `scripts/lib/correlate.py` | support-library |
| `scripts/lib/correlation_engine.sh` | support-library |
| `scripts/lib/date_utils.sh` | support-library |
| `scripts/lib/file_ops.sh` | support-library |
| `scripts/lib/focus_relevance.sh` | support-library |
| `scripts/lib/github_ops.sh` | support-library |
| `scripts/lib/health_ops.sh` | support-library |
| `scripts/lib/insight_score.sh` | support-library |
| `scripts/lib/insight_store.sh` | support-library |
| `scripts/lib/loader.sh` | support-library |
| `scripts/lib/oauth.sh` | support-library |
| `scripts/lib/spoon_budget.sh` | support-library |
| `scripts/lib/time_tracking.sh` | support-library |
| `scripts/logs.sh` | support-utility |
| `scripts/media_converter.sh` | support-utility |
| `scripts/meds.sh` | daily-core |
| `scripts/migrate_data.sh` | support-utility |
| `scripts/mkproject_py.sh` | support-utility |
| `scripts/my_progress.sh` | daily-core |
| `scripts/network_info.sh` | support-utility |
| `scripts/new_script.sh` | support-utility |
| `scripts/observer.sh` | compatibility-wrapper |
| `scripts/open_file.sh` | support-utility |
| `scripts/pdf_to_markdown.sh` | support-utility |
| `scripts/process_manager.sh` | support-utility |
| `scripts/remind_me.sh` | daily-core |
| `scripts/repair_todo_done.sh` | support-utility |
| `scripts/repo_tracker.sh` | daily-core |
| `scripts/review_clutter.sh` | support-utility |
| `scripts/run_with_modern_bash.sh` | support-utility |
| `scripts/schedule.sh` | daily-core |
| `scripts/setup_weekly_review.sh` | support-utility |
| `scripts/spec_helper.sh` | support-utility |
| `scripts/spoon_manager.sh` | daily-core |
| `scripts/start_project.sh` | support-utility |
| `scripts/startday.sh` | daily-core |
| `scripts/status.sh` | daily-core |
| `scripts/system_info.sh` | support-utility |
| `scripts/take_a_break.sh` | daily-core |
| `scripts/text_processor.sh` | support-utility |
| `scripts/tidy_downloads.sh` | support-utility |
| `scripts/time_tracker.sh` | daily-core |
| `scripts/todo.sh` | daily-core |
| `scripts/unpacker.sh` | support-utility |
| `scripts/validate_env.sh` | support-utility |
| `scripts/weather.sh` | support-utility |
| `scripts/week_in_review.sh` | daily-core |
| `scripts/whatis.sh` | support-utility |

## Bin Entrypoints

- `bin/coach-chat.py`
- `bin/cyborg`
- `bin/cyborg-sync`
- `bin/dhp-brand.sh`
- `bin/dhp-chain.sh`
- `bin/dhp-coach.sh`
- `bin/dhp-content.sh`
- `bin/dhp-context.sh`
- `bin/dhp-copy.sh`
- `bin/dhp-creative.sh`
- `bin/dhp-finance.sh`
- `bin/dhp-lib.sh`
- `bin/dhp-market.sh`
- `bin/dhp-memory-search.sh`
- `bin/dhp-memory.sh`
- `bin/dhp-morphling.sh`
- `bin/dhp-narrative.sh`
- `bin/dhp-project.sh`
- `bin/dhp-research.sh`
- `bin/dhp-shared.sh`
- `bin/dhp-stoic.sh`
- `bin/dhp-strategy.sh`
- `bin/dhp-swarm.py`
- `bin/dhp-tech.sh`
- `bin/dhp-utils.sh`
- `bin/dispatch.sh`
- `bin/morphling.sh`
- `bin/swipe.sh`

## Dispatcher Wrappers

- `bin/dhp-*.sh` files: 21

- `bin/dhp-brand.sh`
- `bin/dhp-chain.sh`
- `bin/dhp-coach.sh`
- `bin/dhp-content.sh`
- `bin/dhp-context.sh`
- `bin/dhp-copy.sh`
- `bin/dhp-creative.sh`
- `bin/dhp-finance.sh`
- `bin/dhp-lib.sh`
- `bin/dhp-market.sh`
- `bin/dhp-memory-search.sh`
- `bin/dhp-memory.sh`
- `bin/dhp-morphling.sh`
- `bin/dhp-narrative.sh`
- `bin/dhp-project.sh`
- `bin/dhp-research.sh`
- `bin/dhp-shared.sh`
- `bin/dhp-stoic.sh`
- `bin/dhp-strategy.sh`
- `bin/dhp-tech.sh`
- `bin/dhp-utils.sh`

## Top-Level Shell Scripts

- `scripts/ai_suggest.sh`
- `scripts/app_launcher.sh`
- `scripts/archive_manager.sh`
- `scripts/backup_data.sh`
- `scripts/backup_project.sh`
- `scripts/bash_graph.sh`
- `scripts/bash_intel.sh`
- `scripts/battery_check.sh`
- `scripts/blog.sh`
- `scripts/blog_recent_content.sh`
- `scripts/cheatsheet.sh`
- `scripts/clipboard_manager.sh`
- `scripts/context.sh`
- `scripts/correlate.sh`
- `scripts/cyborg_scoped_site_check.sh`
- `scripts/data_validate.sh`
- `scripts/dev_shortcuts.sh`
- `scripts/done.sh`
- `scripts/dotfiles_check.sh`
- `scripts/drive.sh`
- `scripts/dump.sh`
- `scripts/duplicate_finder.sh`
- `scripts/file_organizer.sh`
- `scripts/findbig.sh`
- `scripts/findtext.sh`
- `scripts/fitbit_import.sh`
- `scripts/fitbit_sync.sh`
- `scripts/focus.sh`
- `scripts/g.sh`
- `scripts/gcal.sh`
- `scripts/generate_report.sh`
- `scripts/gh-projects.sh`
- `scripts/github_helper.sh`
- `scripts/gitnexus.sh`
- `scripts/goodevening.sh`
- `scripts/grab_all_text.sh`
- `scripts/greeting.sh`
- `scripts/health.sh`
- `scripts/howto.sh`
- `scripts/idea.sh`
- `scripts/insight.sh`
- `scripts/inventory.sh`
- `scripts/journal.sh`
- `scripts/logs.sh`
- `scripts/media_converter.sh`
- `scripts/meds.sh`
- `scripts/migrate_data.sh`
- `scripts/mkproject_py.sh`
- `scripts/my_progress.sh`
- `scripts/network_info.sh`
- `scripts/new_script.sh`
- `scripts/observer.sh`
- `scripts/open_file.sh`
- `scripts/pdf_to_markdown.sh`
- `scripts/process_manager.sh`
- `scripts/remind_me.sh`
- `scripts/repair_todo_done.sh`
- `scripts/repo_tracker.sh`
- `scripts/review_clutter.sh`
- `scripts/run_with_modern_bash.sh`
- `scripts/schedule.sh`
- `scripts/setup_weekly_review.sh`
- `scripts/spec_helper.sh`
- `scripts/spoon_manager.sh`
- `scripts/start_project.sh`
- `scripts/startday.sh`
- `scripts/status.sh`
- `scripts/system_info.sh`
- `scripts/take_a_break.sh`
- `scripts/text_processor.sh`
- `scripts/tidy_downloads.sh`
- `scripts/time_tracker.sh`
- `scripts/todo.sh`
- `scripts/unpacker.sh`
- `scripts/validate_env.sh`
- `scripts/weather.sh`
- `scripts/week_in_review.sh`
- `scripts/whatis.sh`

## Sourced Shell Libraries

- `scripts/lib/blog_common.sh`
- `scripts/lib/blog_gen.sh`
- `scripts/lib/blog_lifecycle.sh`
- `scripts/lib/blog_ops.sh`
- `scripts/lib/coach_brief.sh`
- `scripts/lib/coach_chat.sh`
- `scripts/lib/coach_metrics.sh`
- `scripts/lib/coach_ops.sh`
- `scripts/lib/coach_prebrief.sh`
- `scripts/lib/coach_prompts.sh`
- `scripts/lib/coach_scoring.sh`
- `scripts/lib/coaching.sh`
- `scripts/lib/common.sh`
- `scripts/lib/config.sh`
- `scripts/lib/context_capture.sh`
- `scripts/lib/correlation_engine.sh`
- `scripts/lib/date_utils.sh`
- `scripts/lib/file_ops.sh`
- `scripts/lib/focus_relevance.sh`
- `scripts/lib/github_ops.sh`
- `scripts/lib/health_ops.sh`
- `scripts/lib/insight_score.sh`
- `scripts/lib/insight_store.sh`
- `scripts/lib/loader.sh`
- `scripts/lib/oauth.sh`
- `scripts/lib/spoon_budget.sh`
- `scripts/lib/time_tracking.sh`
