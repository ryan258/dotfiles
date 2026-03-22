# Safety Rules (Security)

This page explains how we keep your computer and your personal data safe while using these tools.

## Supported Versions

We only provide safety updates for the main, newest version of these tools (`main` branch).

## Found a Problem?

If you find a way someone could hack or break these tools, please let us know immediately! Open an issue on GitHub and title it "Security Vulnerability". Please tell us:
1. What the problem is.
2. How to make the problem happen.
3. How bad you think it is.

We will reply within two days!

## How to Keep Your Stuff Safe

Follow these rules to keep your computer safe:

* **Hide Your Passwords:** NEVER save your API keys (AI passwords) directly into your code! Always put them in your `.env` file (which is specifically hidden from the public).
* **Change Passwords Often:** It is smart to get a new AI password every few months, just in case.
* **Be Careful with Bookmarks:** If you make a bookmark that runs a command automatically, make sure you know exactly what that command does!
* **Update Your Computer:** Always install the newest updates for your Mac or Linux computer.

## Where to Put Passwords

* **AI Passwords:** Put your OpenRouter password in the hidden `.env` file in this folder.
* **GitHub Passwords:** Save your GitHub password in a hidden file called `~/.github_token`. Make sure no other users on your computer can read it.

## Your Privacy

These tools are built for you alone. We do not spy on you or look at your data. All of your diary entries, health logs, and chores are saved directly onto your own computer in `~/.config/dotfiles-data/`. No one else can see them!

**When using AI:** To get answers, the tools do send your questions to the AI company (OpenRouter). Because of this, please DO NOT send your banking information, real passwords, or deep secrets to the AI helpers.

## What to Do in an Emergency

If you accidentally share your password online:
1. Go to the website and delete the password immediately so no one can use it.
2. Figure out what the hacker might have seen.
3. Make a brand new password.
