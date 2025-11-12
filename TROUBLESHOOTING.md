# Troubleshooting Guide

This document provides solutions to common issues encountered when setting up and using the `dotfiles` project.

## General Issues

### Scripts not found or not executable

**Problem:** You run a command like `todo` or `g` and get "command not found" or "permission denied".

**Solution:**
1.  **Ensure `bootstrap.sh` was run:** The `bootstrap.sh` script sets up your `PATH` and makes scripts executable. Run it again:
    ```bash
    cd ~/dotfiles
    ./bootstrap.sh
    ```
2.  **Restart your shell:** After running `bootstrap.sh`, close and reopen your terminal, or run `source ~/.zshrc`.
3.  **Check `PATH`:** Verify that `~/dotfiles/scripts` and `~/dotfiles/bin` are in your `PATH`. You can check with:
    ```bash
    echo $PATH
    ```
    If they are missing, ensure `~/.zshenv` contains the correct `export PATH` lines and is being sourced.
4.  **Check permissions:** Ensure the scripts are executable:
    ```bash
    chmod +x ~/dotfiles/scripts/*.sh ~/dotfiles/bin/*.sh
    ```

### `source` command warnings (SC1090, SC1091) from ShellCheck

**Problem:** When running `shellcheck`, you see warnings like `SC1090` or `SC1091` about not being able to follow sourced files (e.g., `.env`, `dhp-shared.sh`).

**Solution:** These are often informational warnings in the context of dotfiles where files are sourced dynamically or are not meant to be standalone. You can generally ignore them. If you want to suppress them for specific lines, you can add ` # shellcheck disable=SC1090` to the end of the line.

## AI Dispatcher Issues

### `OPENROUTER_API_KEY is not set` error

**Problem:** When running an AI dispatcher (e.g., `tech`, `content`), you get an error that `OPENROUTER_API_KEY` is not set.

**Solution:**
1.  **Create `.env` file:** Copy `.env.example` to `.env` in your `~/dotfiles` directory:
    ```bash
    cp ~/dotfiles/.env.example ~/dotfiles/.env
    ```
2.  **Add API Key:** Edit `~/dotfiles/.env` and add your OpenRouter API key:
    ```
    OPENROUTER_API_KEY="sk-your-api-key-here"
    ```
3.  **Restart your shell:** Close and reopen your terminal, or run `source ~/.zshrc`.

### `GitHub token not found` or `insecure permissions` error

**Problem:** When running `github_helper.sh` or related scripts, you get an error about the GitHub token.

**Solution:**
1.  **Create token file:** Create a file at `~/.github_token` and paste your GitHub Personal Access Token into it.
2.  **Set permissions:** Ensure the file has secure permissions (read/write for owner only):
    ```bash
    chmod 600 ~/.github_token
    ```
    The `bootstrap.sh` script should do this automatically if the file exists.

## macOS Specific Issues

### `date` command errors (`-v` flag not working)

**Problem:** Some scripts use `date -v` (e.g., `date -v-7d`) which is a GNU `date` extension or macOS-specific. If you are on a different Unix-like system, this might not work.

**Solution:** The dotfiles are primarily designed for macOS. If you are on Linux, you might need to install `coreutils` (for GNU `date`) or adjust the `date` commands to use your system's `date` syntax.

### `osascript` errors

**Problem:** Scripts using `osascript` for notifications or other macOS integrations fail.

**Solution:** Ensure you are running on macOS. `osascript` is a macOS-specific tool.

## Reporting Bugs

If you encounter a bug not covered here, please open an issue on the [GitHub repository](https://github.com/ryan258/dotfiles/issues). Please include:
*   The command you ran.
*   The full error message.
*   Your operating system and shell version (`uname -a`, `zsh --version`).
*   Steps to reproduce the issue.
