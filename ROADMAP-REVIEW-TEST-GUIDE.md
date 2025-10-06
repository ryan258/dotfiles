# Handbook & Testing Guide for New Dotfiles Features

**Purpose:** This guide is your handbook for understanding and testing the new scripts and features we've added to your dotfiles. Use it to familiarize yourself with the new tools and ensure they work as expected.

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

## 3. Testing the `projects` Command

This command helps you find and get details about projects you haven't touched in a while.

### How to Use
-   To find old projects: `projects forgotten`
-   To get details on a project: `projects recall <project_name>`

### Test Plan
1.  **Find Forgotten Projects:**
    -   Run `projects forgotten`.
    -   **Expected:** A list of projects in `~/Projects` that haven't been modified in over 60 days. (This list might be empty if all your projects are active).

2.  **Recall a Project:**
    -   Pick a project name from the `forgotten` list (or any project in `~/Projects`).
    -   Run `projects recall <project_name>`.
    -   **Expected:** You should see a summary card with the project's last modification date, last commit, a preview of its README, and its full path.

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
