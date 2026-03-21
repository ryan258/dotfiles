# Energy-Contingent Roadmap

> "The goal is a pivot from building infrastructure to generating capability. This roadmap decouples tasks from the calendar, allowing progress to match your biology."

## TL;DR

- Pick tasks based on today’s energy, not the calendar.
- If `health check` trips, stop high‑energy work.
- Use this roadmap as a menu, not a deadline list.

## 🛑 Circuit Breaker Rules

_If `health.sh check` returns "CIRCUIT BREAKER TRIPPED":_

1.  **Stop** all High Energy work immediately.
2.  Switch to **Recovery** or select **one** item from the Low Energy Menu.
3.  Extend all deadlines by 24 hours.

---

## ⚡️ High Energy Menu (7-10/10)

_Requires: Focus, Creative Strategy, Complex Coding. Do these ONLY when you feel capable._

### Priority: Reliability & Safety

- [ ] **T1 · Morning Hook Smoke Test:** Implement `zsh -ic startday` automated check for login hooks.
- [ ] **O4 · API Key Governance:** Implement rotation reminders and `dispatcher auth test`.

### Priority: Specialist Expansion

- [ ] **S1 · Build Niche Specialists:** Create additional YAML definitions in ai-staff-hq (15+ already defined).
- [ ] **S3 · Advanced Workflow Automation:** Extend multi-agent flows beyond existing dhp-chain and dhp-project.

### Priority: Content

- [ ] **Draft Deep Guide:** Write a new architectural guide or "God Mode" reflection.
- [ ] **Strategic Positioning:** Define the long-term vision for the "AI Staff" capability.

---

## 🔋 Low Energy Menu (1-4/10)

_Requires: Low Cognitive Load, Repetition, Admin. Do these when recovering or in brain fog._

### Administrative

- [ ] **B8 · Idea Syncing:** Run `blog ideas sync` to update the backlog.
- [ ] **Backup Verification:** Run `scripts/backup_data.sh` and verify output.
- [ ] **Update Documentation:** Fix typos or minor clarity issues in `README.md`.

### Verification (Rote Work)

- [ ] **T3 · GitHub Helper Check:** Manually verify the PAT instructions in `TROUBLESHOOTING.md`.
- [ ] **Log Review:** Read through recent logs in `logs/` to spot patterns (passive).
- [ ] **Dependency Audit:** Check for updates to `requirements.txt` (run `pip list --outdated`).

### Capability "Product" Polish

- [ ] **S2 · Specialist Validator:** Write simple linting rules for YAML files.
- [ ] **Screenshot Documentation:** Take screenshots of `dashboard` or `graph_runner` output for product briefs.

---

## 🧊 Icebox (Deprioritized High-Friction Items)

_These generate stress without immediate capability gain. Defer until energy allows._

- [ ] S-Corp Formation / Legal Entity Setup
- [ ] Complex Tax Accounting / Payroll
- [ ] Micro-consulting / Synchronous Sales Calls

---

## Related Docs

- [Documentation Index](README.md)
- [Daily Loop Handbook](daily-loop-handbook.md)
- [AI Handbook](ai-handbook.md)
- [Autopilot Happy Path](autopilot-happy-path.md)
- [Troubleshooting](../TROUBLESHOOTING.md)
