# How We Number Our Updates

This page explains how we name the different versions of the blog and these computer tools.

## The Version Numbers

We use a system with three numbers, like **1.2.3**. 
Each number means something different:

- **The First Number (Big Changes):** We change this number (like going from 1.0.0 to 2.0.0) when we completely change how the site looks or add massive new tools (like adding Video Support).
- **The Middle Number (Small Features):** We change this number (like going from 1.2.0 to 1.3.0) when we add a cool new button or a new AI helper that wasn't there before.
- **The Last Number (Bug Fixes):** We change this number (like going from 1.2.3 to 1.2.4) when we just fix a typo or fix a broken link. No new features, just cleaning up!

## The Work Steps

When you want to save your work, follow these steps:
1. **Check Your Version:** Type `blog version` to see what number we are currently on.
2. **Do Your Work:** Write your article or fix your code.
3. **Change the Number:** When you are completely done, type `blog version bump patch` (or `minor`, or `major`). 
   - The computer will save your work, bump the number up, and officially log what you did into your daily diary!

## Fast Commands

There is a built-in helper that does the math for you:
- `blog version bump patch` -> updates `1.0.0` to `1.0.1`
- `blog version bump minor` -> updates `1.1.0` to `1.2.0`
- `blog version bump major` -> updates `1.5.0` to `2.0.0`
