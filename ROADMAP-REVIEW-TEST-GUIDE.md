# Handbook & Testing Guide for New Dotfiles Features

**Purpose:** This guide is your handbook for understanding and testing the new scripts and features we've added to your dotfiles. Use it to familiarize yourself with the new tools and ensure they work as expected.

---

## 0. Initial Setup for GitHub Integration

This new system connects directly to GitHub, so there's one crucial setup step.

### What to Check
1.  **Create a GitHub Personal Access Token (PAT):** If you haven't already, create a **classic** token at [https://github.com/settings/tokens/new](https://github.com/settings/tokens/new).
2.  **Token Scope:** Ensure the token has the **`repo`** scope selected.
3.  **Save the Token:** The token must be saved in a file at `~/.github_token`. The command `cat ~/.github_token` should display your token.
4.  **Dependencies:** Ensure `curl` and `jq` are installed (`brew install jq`).

---

## 1. Testing the Enhanced `status` Command

The `status` command is your new go-to for mid-day context recovery. It gives you a complete snapshot of what you're working on.

### How to Use
Simply run:
```bash
status
```

### What to Check
- **🧭 WHERE YOU ARE:** Shows your current directory, git branch (if any), and the very last journal entry you made.
- **📝 TODAY'S JOURNAL:** Lists all journal entries you've made since midnight.
- **🚀 ACTIVE PROJECT:** If you're inside a `~/Projects` subdirectory, it shows the project name and the last git commit message.
- **✅ TASKS:** Your current to-do list.

### Test Plan
1.  **Inside a Project:**
    -   `cd` into one of your projects under `~/Projects`.
    -   Make sure it's a git repository.
    -   Run `status`.
    -   **Expected:** You should see the project name, git branch, and last commit message.

2.  **Outside a Project:**
    -   `cd ~`
    -   Run `status`.
    -   **Expected:** The "ACTIVE PROJECT" section should indicate you're not in a project directory.

3.  **With Fresh Journal Entries:**
    -   Add a new journal entry: `journal "Testing the new status command."`
    -   Run `status`.
    -   **Expected:** Your new entry should appear under "TODAY'S JOURNAL" and as the "Last journal entry".

---

## 2. Testing the Enhanced `goodevening` Command

The `goodevening` command is designed to be a powerful end-of-day ritual to close out your work.

### How to Use
Run at the end of your day:
```bash
goodevening
```

### What to Check
- **✅ COMPLETED TODAY:** Shows tasks you've marked as done today.
- **📝 TODAY'S JOURNAL:** Your journal entries from today.
- **🚀 ACTIVE PROJECTS:** Lists any projects under `~/Projects` that have uncommitted git changes.
- **Interactive Prompt:** Asks you for a note for "tomorrow-you".
- **Cleanup:** Removes completed tasks older than 7 days from your `~/.todo_done.txt` file.

### Test Plan
1.  **Prepare the Test:**
    -   Add a task: `todo add "Test the goodevening script"`
    -   Complete the task: `todo done 1` (or the correct number)
    -   `cd` into a project under `~/Projects` and create a new file or modify one without committing.
    -   `cd ~` (run `goodevening` from your home directory).

2.  **Run the Command:**
    -   Run `goodevening`.
    -   **Expected:**
        -   You should see the task you just completed under "COMPLETED TODAY".
        -   You should see the project with uncommitted changes listed.
        -   You should be prompted for a note.

3.  **Verify the Note:**
    -   Enter a message like "Tested goodevening script." at the prompt.
    -   Check your journal file: `tail -n 1 ~/.daily_journal.txt`
    -   **Expected:** The last line should be your "EOD Note".

---

## 3. Testing the `projects` Command (GitHub Version)

This command now helps you find and get details about projects directly from your GitHub account.

### How to Use
-   To find old projects on GitHub: `projects forgotten`
-   To get details on a GitHub repo: `projects recall <repo_name>`

### What to Check
The commands should now reflect the state of your repositories on GitHub, not your local machine.

### Test Plan
1.  **Find Forgotten Projects:**
    -   Run `projects forgotten`.
    -   **Expected:** A list of your GitHub repositories that you haven't pushed to in over 60 days.

2.  **Recall a Project:**
    -   Pick a repository name (e.g., `dotfiles`).
    -   Run `projects recall dotfiles`.
    -   **Expected:** A summary card showing the last push date, the message from the very last commit, a preview of the README from GitHub, and the URL to the repository.

---

## 4. Testing the `blog` Command

This is your new toolkit for managing your blog content workflow.

### How to Use
-   `blog status`: Get an overview of your blog.
-   `blog stubs`: List all posts marked as "content stubs".
-   `blog random`: Open a random stub file for editing.
-   `blog recent`: See recently modified posts.

### Test Plan
1.  **Check Status:**
    -   Run `blog status`.
    -   **Expected:** See total post count, number of stubs, and the date of the last update to the blog repository.

2.  **List and Edit Stubs:**
    -   Run `blog stubs`.
    -   **Expected:** A list of all markdown files containing the phrase "content stub".
    -   Run `blog random`.
    -   **Expected:** It should tell you which file it's opening and then open it in VS Code (if installed) or the default editor.

3.  **Check Recent Posts:**
    -   Open any blog post file in `~/Projects/my-ms-ai-blog/content/posts/` and save it (even with no changes) to update its modification time.
    -   Run `blog recent`.
    -   **Expected:** The file you just saved should appear at the top of the list.

---

## 5. Testing the GitHub-Powered `startday` Command

The `startday` script's "Active Projects" section has been updated to reflect your recent GitHub activity, making it consistent across machines.

### How to Use
Simply run:
```bash
startday
```

### What to Check
- **🚀 ACTIVE PROJECTS:** This section should now be titled "ACTIVE PROJECTS (pushed to GitHub in last 7 days)".
- It should list repositories you've recently pushed to, not just local folders.

### Test Plan
1.  **Push to a Repo:**
    -   Go to any project on your development machine and push a change to GitHub.
2.  **Run `startday`:**
    -   On *any* machine (your laptop or desktop), run `startday`.
    -   **Expected:** The repository you just pushed to should appear at the top of the "ACTIVE PROJECTS" list, marked as pushed "today".
3.  **Smoke Test After Shell Changes:**
    -   Reset the daily guard so the login hook fires: `rm -f /tmp/startday_ran_today_$(date +%Y%m%d)`.
    -   Launch a fresh shell: `zsh -ic 'echo ok'`.
    -   **Expected:** `startday` runs once without syntax errors, prints the morning dashboard, and the shell continues to `echo ok`.

---

## 🧪 Upcoming Additions (Next Round)

- **`startday` smoke test:** After fixing the parse error, add a quick command (`zsh -ic startday`) to ensure the login hook runs without syntax errors.
- **Happy Path walk-through:** Once documented, add a checklist to rehearse the `startday → status → goodevening` flow weekly.
