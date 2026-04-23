# The Master Plan (Roadmap)

_Last updated: April 23, 2026 (Version 2.2.67 — OAuth helpers, Drive auth hardening, coach control-surface improvements, and dispatcher/config cleanup)_

## 0. The Big Goal

- **Goal:** Make my computer a super helpful assistant that runs my life and publishes my blog automatically.
- **Where it runs:** On Apple Mac and Linux computers. The blog gets published to the internet automatically when we save our work.
- **How it's built:** We use simple computer scripts (Bash) for daily chores. We use smarter code (Python) for really hard things like the `Cyborg` chatbot and making the AI helpers work together.
- **The Rules:** It must never crash. It must do things automatically. It must track energy using "Spoon Theory." It must be so easy to use that I can use it even on days when my brain feels foggy.

## 1. What We Actually Built So Far

- **Just Finished (March 2026):**
  - **The AI Coach:** A smart system that checks how I am doing. It looks at my tasks, health, and code. It stops the AI from making things up (hallucinating) and coaches me based on my real energy.
  - **Cyborg Lab Chatbot:** A huge 4,900-line tool that reads my project folders, builds a plan, and automatically writes whole blog posts for me.
  - **The Morphling Helper:** A magic helper that can suddenly become any expert you need. It teams up with Cyborg to build projects from just an idea.
  - **Autopilot Mode:** Fast shortcuts (like typing `ap` or `apc`) that do massive chores with one button. Great for brain-fog days!
  - **More AI Tools:** We now have 13 fast tools to help with writing, coding, and paying taxes.
  - **Code Cleanup:** We cleaned up the entire system to make it run faster and safer.
  - **Testing:** Added 37 tests to prove our code actually works.
  - **Smart Code Memory:** Added GitNexus so the AI understands all the secret connections in our code.
  - **Ideas Box:** Built a place to save cool ideas and turn them into real tasks later.
  - **The Detective System:** A tool that helps us test if our ideas are actually true.

- **Finished Earlier (January 2026):**
  - **The Foundation:** 66 scripts to automate boring daily chores.
  - **Energy Tracking (Spoons):** A way to track daily energy so I don't burn out.
  - **Data Finder:** A tool that connects my health data to the work I get done.
  - **AI Suggestions:** The computer guesses what I want to do based on my health and my tasks.
  - **Security:** Locked down our system so hackers can't get in (A+ grade!).
  - **The Helpers:** Built a full team of 68 AI experts.
  - **Blog Pipeline:** Built the exact steps needed to publish the blog perfectly.

- **What We Are Doing Right Now:**
  - Making the Cyborg chatbot run perfectly on any project without crashing.
  - Making the AI Coach even smarter so it stops rejecting real evidence by mistake.

- **Coming Up Next:**
  - Hiding our API passwords better so they stay safe.
  - Setting up alarms so we don't accidentally spend too much money on AI.
  - Making the computer run automatic tests every single morning so we never wake up to a broken system.

- **Way In The Future:**
  - Adding even more AI experts to our team.
  - Letting the daily routines search our huge library of old notes automatically.
  - Setting up ways to publish the blog to different websites.

## 2. The Task List

Letters mean: `R` Reliability, `C` Config, `O` Watching, `W` Work, `B` Blog, `T` Tests, `S` Staff, `A` Robot, `K` Coach.

### 2.1 The AI Coach (FINISHED)
**Status:** Works perfectly. It gives me a briefing every morning and evening.
**What it does:** Reads my diary, scores how focused I am, tracks my energy crashing in the afternoon, stops the AI from lying, and changes its tone if I am too tired to work hard.

### 2.2 Cyborg Lab Chatbot (FINISHED)
**Status:** Works perfectly. Runs on autopilot or chat mode.
**What it does:** Reads any folder, builds a plan, generates full blog articles, remembers what we talked about yesterday, and asks easy multiple-choice questions (A, B, C, D).

### 2.3 Watching the System & Passwords
**Next steps:** 
- [ ] Build a tool to manage our passwords and rotate them safely.
- [ ] Build a tool that warns us if the AI costs get too high this month.

### 2.4 Making Daily Chores Easier
**Finished steps:**
- Built shortcuts like `ap` to run things on autopilot.
- Made typing easier for people with brain fog.
- Built the `idea.sh` backlog tool.

### 2.5 The Blog Factory
**Status:** The system can write and publish a blog entirely by itself. It uses Cyborg to read projects and turns them into guides.
**Next step:** 
- [ ] Allow it to publish to different servers, not just DigitalOcean.

### 2.6 Testing Everything
**Status:** We have tests for the Coach, the Helpers, the APIs, and everything else.
**Next steps:**
- [ ] Run a test the second I log in every morning to prove nothing broke while I slept.
- [ ] Run a full "Happy-path" test (morning to night) automatically.
- [ ] Update the instructions for connecting to GitHub.

### 2.7 AI Staff Help Team
**Status:** 68 helpers are ready to work. We added new ones for money, universal help (Morphling), and coaching. 
**Next steps:**
- [ ] Add the final weird, extra experts so we have more than 68.
- [ ] Build a tool that double-checks their instruction files to make sure they are written perfectly.

### 2.8 Cleaning Bad Code
**Status:** Finished! We fixed huge messes, split up the giant AI Coach script into smaller pieces, and made sure errors look the same everywhere.

### 2.9 The AI Memory Brain
**Status:** The AI can remember answers from old projects. We built a library space for this.
**Next steps:**
- [ ] Have the morning Coach briefing automatically pull up memories from the library.
- [ ] Make the computer automatically file our old diary notes into the library so we don't have to do it ourselves.

## 3. The Report Card (March 20, 2026)

- **Tests:** 37 files full of tests checking every part of the system.
- **Huge Bugs:** Zero.
- **Security Grade:** A+ (We are extremely safe against hackers).
- **Code Grade:** A+ (Clean, fast, and doesn't crash).
- **Computers:** Works on Mac and Linux.
- **Numbers:** 66 chores automated, 13 fast AI tools, 21 shared toolboxes. 
- **Python Power:** Cyborg Lab is massive (almost 5,000 lines of code) and handles all the huge tasks.

---
_Note to self: Don't make a new to-do list file. Just change this one! Keep everything in one spot._
