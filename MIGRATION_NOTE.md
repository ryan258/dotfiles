# Migration Notes

## Version 2.0.0 - November 12, 2025

### Overview
Version 2.0.0 is a **non-breaking security and quality release**. All existing data remains compatible, but several important behavioral improvements and fixes have been implemented.

### What Changed

**Security & Reliability:**
- Path validation now uses Python's `os.path.realpath()` for cross-platform compatibility (requires python3, which is standard on macOS/Linux)
- External blog directories (e.g., `/var/www/blog`) are now fully supported - validation only applies to paths under `$HOME`
- Test suite now uses isolated temporary directories to prevent accidental data corruption
- All API dispatchers now properly log calls and handle errors correctly

**Cross-Platform Compatibility:**
- `howto.sh` now detects OS and uses appropriate commands (macOS `stat -f` vs Linux `find -printf`)
- All scripts verified working on both macOS and Linux

**Bug Fixes:**
- Fixed jq JSON payload builder that was preventing temperature/max_tokens from being sent to API
- Fixed newline replacement in `startday`/`goodevening` that was corrupting text
- Fixed glob pattern matching in `tidy_downloads.sh`
- Fixed app launcher argument passing in `g.sh`
- Fixed `health.sh` export to truncate instead of append
- Fixed git config errors in `github_helper.sh`

### Migration Required?

**No data migration required.** Your existing data files in `~/.config/dotfiles-data/` work as-is.

### New Requirements

1. **Python 3:** Now required for path validation (already installed on macOS/Linux by default)
   ```bash
   # Verify you have it:
   python3 --version
   ```

2. **External Blog Paths:** If you use `BLOG_DIR` pointing outside `$HOME`, it now works correctly without validation errors

### Recommended Actions

1. **Review Security Policy:** Check [SECURITY.md](SECURITY.md) for security best practices
2. **Check Troubleshooting Guide:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
3. **Verify Installation:**
   ```bash
   dotfiles_check
   # Should report: "✅ All systems OK!"
   ```

4. **Run Test Suite:**
   ```bash
   bats tests/test_todo.sh
   # Should show all tests passing
   ```

### Breaking Changes

None! All existing workflows continue to work.

---

## Data Migration Complete - November 1, 2025

Your personal data has been successfully migrated from scattered locations to the centralized data directory.

## Migrated Files

### From Home Directory → ~/.config/dotfiles-data/

1. **Health Appointments**
   - Old: `~/.health_appointments.txt`
   - New: `~/.config/dotfiles-data/health.txt`
   - Format updated to: `APPT|YYYY-MM-DD HH:MM|description`
   - ✅ 3 appointments migrated successfully

2. **Todo Lists**
   - Old: `~/.todo_list.txt` → New: `~/.config/dotfiles-data/todo.txt`
   - Old: `~/.todo_done.txt` → New: `~/.config/dotfiles-data/todo_done.txt`
   - ✅ 4 active tasks + 4 completed tasks migrated

3. **Journal**
   - Old: `~/journal.txt`
   - New: `~/.config/dotfiles-data/journal.txt`
   - ✅ 6 journal entries migrated

## Verified Working

All scripts tested and confirmed working with migrated data:
- ✅ `todo.sh list` - Shows all 4 tasks
- ✅ `journal.sh` - Shows all 6 entries
- ✅ `health.sh list` - Shows 2 upcoming appointments (1 past appointment filtered out)

## Old Files Still Present

The following old files are still in your home directory as backups:
- `~/.health_appointments.txt`
- `~/.todo_list.txt`
- `~/.todo_done.txt`
- `~/journal.txt`
- `~/health_breaks.log` (purpose unknown - not migrated)

**Recommended Action:** After verifying everything works for a few days, you can safely delete these old files:

```bash
# Verify data is good first, then:
rm ~/.health_appointments.txt
rm ~/.todo_list.txt
rm ~/.todo_done.txt
rm ~/journal.txt
# Check what health_breaks.log is before deleting
```

## What Changed

The centralization fix in Phase 1 (Fix #3) updated all the **scripts** to point to the new location, but didn't migrate your existing **data**. This migration completes that process.

## Benefits

- ✅ Single backup location: `~/.config/dotfiles-data/`
- ✅ Cleaner home directory
- ✅ All scripts now reading from correct location
- ✅ No more data scattered across multiple locations
