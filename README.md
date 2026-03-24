# Welcome to the Dotfiles Helper

This is a set of tools you run on your computer. It helps you get through your workday even when your brain feels foggy. It was made for someone with MS (multiple sclerosis), which can make it hard to think or remember things. These tools do the hard work for you.

## What It Does

- Automatically runs your daily routine: `startday`, `status`, and `goodevening`. A smart AI coach talks to you at each step.
- Saves your tasks, your diary, your health, and your energy safely in your folders.
- Gives you 13 AI helpers (like a Tech Expert or a Creative Writer) who can do work for you instantly.
- Checks the AI's answers to make sure it doesn't make things up!
- A special robot (Cyborg Lab) can automatically turn your code folders into full blog posts, or build a project from an idea and optionally publish it first.
- **Autopilot Mode:** If you type `ap`, the computer will just do the chores for you while you rest.

## How It's Built

The computer runs scripts (small lists of instructions) when you type a command. 
- The AI helpers are stored in `bin/`.
- The instructions for the tools are in `scripts/`.
- Your saved data is kept safe in `~/.config/dotfiles-data/`.

## The Rule Books

- For the master rules on how everything works, read: `CLAUDE.md`
- For rules about folders, read: `GUARDRAILS.md`
- For the plan of what we will build next, read: `ROADMAP.md`

## How to Install It

Open your terminal and type these lines, hitting Enter after each one:
```bash
git clone https://github.com/ryan258/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./bootstrap.sh
dotfiles-check
```
The `bootstrap.sh` script will install everything you need and make sure the computer knows where to find your new tools.

## What You Need First

- An Apple Mac or a Linux computer.
- Python 3 (a coding language usually already on your computer).
- To make the AI helpers work, you must save an OpenRouter AI password (called an API key) in your `.env` file!

## Fast Commands to Try

```bash
# Your Daily Routine
startday                          # Morning briefing with your AI coach
status                            # Mid-day check-in
goodevening                       # Evening reflection

# Saving Your Work
todo add "Fix the login bug"      # Add a chore to your list
todo top                          # Show the most important chore
focus set "Ship the API"          # Tell the computer what you are focused on

# Your AI Helpers
tech "Why is this crashing?"      # Ask the expert to fix your code
strategy "Should I redesign?"     # Ask the boss for advice
morphling "Look at my folder"     # Ask the magic helper anything

# Autopilot (for brain-fog days)
ap                                # Automatic help with one button
apb "idea"                        # Build + verify + document a new project
apbp "idea"                       # Build + publish + document a new project
```

## Where to Read More

- `docs/README.md` - Start here for a fast 5-minute tour!
- `docs/daily-loop-handbook.md` - Steps for your morning, noon, and evening.
- `docs/ai-handbook.md` - Exactly how to talk to your AI helpers.
- `TROUBLESHOOTING.md` - How to fix common problems.
- `CHANGELOG.md` - A list of everything we have updated.

## Testing
If you ever want to check if the tools are broken, type this to run 37 automatic tests:
```bash
bats tests/*.sh
```
