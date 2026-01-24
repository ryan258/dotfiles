# Product Brief: Health.sh

**Version:** 2.1.0
**Status:** Enterprise Grade / Production Ready
**One-Liner:** A bio-rhythm intelligence tool that correlates energy levels with productivity output to prevent burnout.

## The Problem

For developers with chronic illness (MS, Long Covid, burnout), standard productivity tools are dangerous because they ignore biology. They optimize for "more" rather than "sustainable," leading to boom-and-bust crash cycles.

## The Solution

`health.sh` is a CLI tool that treats your biology as a first-class system metric. It tracks energy (Spoons), symptoms, and appointments, then correlates this data with your actual output (git commits, completed tasks) to reveal your "safe operating window."

## Key Features

- **Circuit Breaker:** Automatically trips if Energy dips below 4/10 or Brain Fog exceeds 6/10, recommending immediate recovery steps to prevent a crash.
- **Correlation Engine:** Analyzes `git log` and `todo.txt` history to show you: "_On days with 4/10 energy, you average 5 tasks. Today you have 2. Stop now._"
- **Spoon Budgeting:** Tracks daily energy expenditure against a "Spoon" budget, preventing overdrafts.
- **Privacy First:** All health data is stored locally in `~/.config/dotfiles-data/health.txt`. No cloud, no tracking.

## Technical Specifications

- **Stack:** Bash 4.0+
- **Path:** `scripts/health.sh`
- **Dependencies:** `grep`, `awk`, `date` (gnu or bsd), `python3` (for advanced stats)

## Usage Example

```bash
# Log morning status
$ health.sh energy 7
> Logged energy level: 7/10

# Log a symptom
$ health.sh symptom "Mild brain fog"
> Logged symptom: Mild brain fog

# Check system status
$ health.sh check
> ✅ SYSTEM OPERATIONAL
> Energy: 7/10 | Fog: N/A

# View correlations
$ health.sh dashboard
> 🏥 HEALTH DASHBOARD (Last 30 Days)
> • Avg Energy: 6.2/10
> • Energy vs. Productivity:
>   - Avg commits on low energy days (1-4): 0.5
>   - Avg commits on high energy days (7-10): 4.2
```

## Value Proposition

It turns "listening to your body" from a vague concept into a hard data point. It gives you permission to rest based on data, not just feelings.
