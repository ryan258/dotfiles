# How to Fix Problems (Troubleshooting)

If a tool is broken or giving you an error, this guide will help you fix it easily!

## 1. "Command Not Found" or "Permission Denied"

**The Problem:** You type a word like `todo` or `startday` and the computer says it doesn't know what that means.
**The Fix:**
1. You probably need to set up the tools again. Open your terminal and type:
   ```bash
   cd ~/dotfiles
   ./bootstrap.sh
   ```
2. Close your terminal window and open a new one. Try the tool again!

## 2. The AI Helpers Say "OPENROUTER_API_KEY is not set"

**The Problem:** The AI tools (like `tech` or `content`) are refusing to work because they are missing their password (API Key).
**The Fix:**
1. You need to create a hidden file to hold your password. Type this:
   ```bash
   cp ~/dotfiles/.env.example ~/dotfiles/.env
   ```
2. Open that new `.env` file and type your password where it says `OPENROUTER_API_KEY="your-password-here"`.
3. Close your terminal, open a new one, and try again!

## 3. GitHub Says "Token Not Found"

**The Problem:** The tools cannot connect to your GitHub account to read your code.
**The Fix:**
Create a file called `~/.github_token` on your computer. Paste your secret GitHub password (Token) inside it and save. 

## 4. `startday` Says "Unable to fetch GitHub activity"

**The Problem:** Your morning or evening summary says it can't find what you did on GitHub today.
**The Fix:**
1. Try forcing the computer to refresh by typing:
   ```bash
   startday refresh --clear-github-cache
   ```
2. Make sure your GitHub name is spelled correctly in your `.env` file!
3. If your internet is broken, it won't be able to connect either. Make sure you are online.

## 5. ShellCheck Gives You Warnings (SC1090)

**The Problem:** If you run a tool that checks your code, it might complain about "ShellCheck Warnings." 
**The Fix:** You can ignore this! This just means the tool doesn't understand how our special files connect. It isn't actually an error.

## 6. Apple Mac Users: `osascript` Errors

**The Problem:** You get a red error that says something about `osascript`.
**The Fix:** That specific tool only works on Apple Mac computers. If you are using Linux, that tool will not work.

## 7. "Observer / Cyborg / Blog Factory is unavailable"

**The Problem:** You run `observer`, `cyborg`, or `blog` and see a message like "Obsidian observer is unavailable. Expected sibling repo: ...".
**The Fix:** These are optional products that live in sibling repos. You have two choices:
- Install the sibling repo at the expected path. The defaults are `~/Projects/obsidian-observer`, `~/Projects/cyborg-agent`, and `~/Projects/blog-factory`.
- Or, point the wrapper at an existing checkout by setting the matching env var: `OBSERVER_HOME`, `CYBORG_HOME`, or `BLOG_FACTORY_HOME` in your `.env`.

The daily loop (`startday`, `status`, `goodevening`) keeps working when these products are missing — only the optional sub-sections degrade. See `docs/blog-factory-boundary.md` and `docs/obsidian-knowledge-graph-framework.md` for the boundary contracts.

## Still Broken? Tell Us!

If none of this helped, please go to our [GitHub Page](https://github.com/ryan258/dotfiles/issues) and click "New Issue" to tell us!
Please be sure to include:
- Exactly what you typed into the computer.
- The red error message the computer printed out.
- What kind of computer you are using (Mac or Linux).
