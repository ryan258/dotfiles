# Dotfiles Project: Fixit List

This document lists the issues found in the dotfiles project and suggests fixes to improve its coherency, robustness, and style. The issues were identified by running `shellcheck` on all the scripts in the `bin/` and `scripts/` directories.

## High Priority: Errors

### 1. `scripts/grab_all_text.sh`: Missing Shebang
- **File:** `scripts/grab_all_text.sh`
- **Issue:** The script is missing a shebang (e.g., `#!/bin/bash`), which makes it non-executable and prevents `shellcheck` from analyzing it correctly.
- **Suggestion:** Add `#!/bin/bash` to the beginning of the script.

---

## Medium Priority: Warnings

### 1. Unused Variables in Dispatcher Scripts
- **Files:** `bin/dhp-content.sh`, `bin/dhp-project.sh`, `bin/dhp-shared.sh`, `scripts/ai_suggest.sh`, `scripts/blog.sh`, `scripts/meds.sh`, `scripts/status.sh`
- **Issue:** Several scripts declare variables that are never used. This can indicate dead code or incomplete refactoring.
- **Examples:**
    - `PARAM_TEMPERATURE` and `PARAM_MAX_TOKENS` in `bin/dhp-content.sh`.
    - `AI_STAFF_DIR` in `bin/dhp-project.sh`.
    - `DIR_NAME` in `scripts/ai_suggest.sh`.
    - `SYSTEM_LOG_FILE` in `scripts/blog.sh`.
- **Suggestion:** Review each unused variable. If it is truly not needed, remove it. If it is part of an incomplete feature, either finish the implementation or remove the dead code.

### 2. Masking Return Values
- **Files:** `scripts/blog.sh`, `scripts/spec_helper.sh`, `scripts/tidy_downloads.sh`
- **Issue:** Declaring and assigning a variable on the same line with a command substitution can mask the return value of the command.
- **Example:** `local title=$(grep ...)` in `scripts/blog.sh`.
- **Suggestion:** Declare the variable first, then assign the value in a separate command to ensure that the script can correctly check the exit code of the command substitution.

### 3. Subshell Scope Issues
- **File:** `scripts/goodevening.sh`
- **Issue:** The `found_issues` variable is modified inside a subshell, so the change is not visible outside the subshell.
- **Suggestion:** Refactor the code to avoid the subshell or use a different method to pass the value out of the subshell (e.g., a temporary file).

### 4. Prefer `mapfile` or `read -a`
- **File:** `scripts/blog.sh`
- **Issue:** Using `VAR=($(command))` is not robust for splitting command output.
- **Suggestion:** Use `mapfile` or `read -a` for safer parsing of command output into an array.

---

## Low Priority: Style and Info

### 1. Check Exit Code Directly
- **Files:** `bin/dhp-brand.sh`, `bin/dhp-content.sh`, `bin/dhp-copy.sh`, `bin/dhp-creative.sh`, `bin/dhp-market.sh`, `bin/dhp-narrative.sh`, `bin/dhp-research.sh`, `bin/dhp-stoic.sh`, `bin/dhp-strategy.sh`, `bin/dhp-tech.sh`, `scripts/goodevening.sh`
- **Issue:** The scripts use `if [ $? -eq 0 ]` to check the exit code of the previous command.
- **Suggestion:** Use `if mycmd;` to check the exit code directly. This is more idiomatic and robust.

### 2. Performance and Style Improvements
- **Files:** Various
- **Issues:**
    - Using `grep | wc -l` instead of `grep -c`.
    - Using `sed` for simple substitutions instead of shell parameter expansion.
    - Using `grep` on `ps` output instead of `pgrep`.
    - Using multiple redirects instead of a command group.
- **Suggestion:** Address these minor performance and style issues to make the scripts more efficient and easier to read.

### 3. Double Quote Variables
- **Files:** `bin/dhp-context.sh`, `bin/swipe.sh`, `scripts/health.sh`, `scripts/meds.sh`
- **Issue:** Variables are not double-quoted, which can lead to globbing and word splitting.
- **Suggestion:** Double quote all variables to prevent unexpected behavior.
