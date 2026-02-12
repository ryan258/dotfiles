# Versioning Policy

This document outlines the versioning strategy for the "My MS & AI Journey" blog and related content.

## Version Format

We use [Semantic Versioning](https://semver.org/) (SemVer) `MAJOR.MINOR.PATCH`.

- **MAJOR**: Significant changes to the site structure, theme, or content strategy (e.g., "Pivot to video", "New Hugo theme").
- **MINOR**: New feature additions, new content sections, or significant operational improvements (e.g., "Added 'Spoon Theory' section", "Implemented automated social posting").
- **PATCH**: Routine content updates, typo fixes, or minor script adjustments (e.g., "Weekly blog post", "Fixed typo in about page").

## Workflow

1.  **Check Current Version**: Use `blog version` to see the current tagged version.
2.  **Make Changes**: Write content, update scripts, etc.
3.  **Bump Version**: Upon completion of a unit of work (e.g., publishing a post), use `blog version bump <level>`.
    - This will create a git tag (e.g., `v1.2.3`).
    - It will verify a clean git state before proceeding.
    - It will log the version bump to your daily journal.

## Tagging

Git tags are the source of truth for versions.
Format: `vX.Y.Z`

## Automation

The `blog.sh` script automates this process:

- `blog version bump patch` -> `v1.0.1`
- `blog version bump minor` -> `v1.1.0`
- `blog version bump major` -> `v2.0.0`
