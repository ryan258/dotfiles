# The AI Helpers Handbook

Your computer comes with a team of 13 very smart AI helpers. They live right in your terminal. This page shows you how to use them to get your work done faster!

---

## 🚀 Meet The Core Team

You can call any of these helpers just by typing their name!

- `tech` - Your coder. Fixes broken computer scripts.
- `content` - Your writer. Writes big blog posts and essays.
- `strategy` - Your boss. Helps you make business decisions.
- `creative` - Your storyteller. Helps you brainstorm wild ideas.
- `brand` - Your voice. Decides how your company should sound.
- `market` - Your researcher. Looks up what competitors are doing.
- `research` - Your librarian. Can read huge folders of text for you.
- `stoic` - Your life coach. Helps you calm down and focus.
- `narrative` - Your plot designer. Thinks of twists for your stories.
- `aicopy` - Your ad writer. Writes fast, catchy emails.
- `finance` - Your accountant. Helps with S-Corp limits and taxes.
- `morphling` - The magic shapeshifter. Can become any expert you need.

---

## 🛠️ How to Talk to Them

### 1. Give them a quick job
Put your question inside quote marks.
```bash
strategy "Should I start a new project or rest today?"
```

### 2. Give them a long job
If an answer is going to take a long time to write, add `--stream`. This makes the text appear on your screen as the AI types it out, like a chat window.
```bash
content --stream "Write a massive guide about computer programming."
```

### 3. Let them read your files
If you want the `tech` helper to look at a broken script you wrote, you can "pipe" the text to the AI using the `|` symbol:
```bash
cat broken-script.sh | tech
```

### 4. Let them work together
You can pass the work from one AI to the next! This is called "chaining". 
Do you want a creative story turned into an advertisement?
```bash
dhp-chain creative aicopy -- "A story about a foggy brain"
```

---

## 🎭 Writing the Blog

When you want the AI to write a blog post for you, it is given a distinct personality (a "persona").

We have three main personas that write your content:
1. **Brenda**: Extremely gentle. She writes for people who are anxious and overwhelmed.
2. **Mark**: The energy saver. He writes guides that focus on clicking the mouse as little as possible.
3. **Sarah**: The organizer. She writes for people who have brain fog and too many unfinished tasks.

You tell the computer to use a persona like this:
```bash
blog generate -p "Brenda" -a blog "Why feeling overwhelmed is okay"
```

---

## ⚙️ Setup and Fixing Things

**To make the AI work:**
You MUST have your OpenRouter password saved inside a hidden file called `.env`. If you do not have this file, the AI helpers will completely ignore you!

**If you don't know who to talk to:**
Just type `ai-suggest`. Your computer will look at your calendar, your diary, and your energy level, and tell you which AI helper you should talk to right now!
