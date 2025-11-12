# Security Policy

This document outlines security procedures and policies for the `dotfiles` project.

## Supported Versions

The following versions of the `dotfiles` project are currently supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| `main`  | ✅ Yes             |

## Reporting a Vulnerability

We take the security of our `dotfiles` seriously. If you discover a security vulnerability, please report it to us as soon as possible.

**How to Report:**
Please open an issue on the GitHub repository and clearly mark it as a "Security Vulnerability". Provide as much detail as possible, including:
*   A clear description of the vulnerability.
*   Steps to reproduce the vulnerability.
*   The potential impact of the vulnerability.
*   Any suggested mitigations (if you have them).

We will acknowledge your report within 48 hours and provide a more detailed response within 7 days.

## Security Best Practices

To ensure the security of your `dotfiles` installation, please follow these best practices:

*   **Keep your API keys secure:** Never commit API keys or other sensitive credentials directly to your git repository. Use `.env` files (which are `.gitignore`d) or environment variables.
*   **Regularly rotate API keys:** Even if not exposed, rotating your API keys periodically is a good security habit.
*   **Review `on-enter` commands:** Be cautious when adding `on-enter` commands to bookmarks in `g.sh`, as these commands are executed automatically. Only use trusted commands.
*   **Maintain file permissions:** Ensure sensitive files (like GitHub tokens) have restrictive file permissions (e.g., `chmod 600`).
*   **Keep software updated:** Regularly update your operating system, Homebrew packages, and any other software used by your dotfiles.

## Credential Management Guide

*   **API Keys:** Store API keys in a `.env` file in your dotfiles root directory. This file is `.gitignore`d to prevent accidental commits.
*   **GitHub Tokens:** Store your GitHub Personal Access Token in `~/.github_token` with `chmod 600` permissions.
*   **Other Secrets:** For other secrets, consider using a dedicated secret management solution like 1Password CLI, HashiCorp Vault, or macOS Keychain.

## Data Privacy Policy

Your `dotfiles` are designed for personal productivity and local data management. We do not collect any personal data. All data (journal entries, todo lists, usage logs) is stored locally on your machine in `~/.config/dotfiles-data/`.

**AI Integration:** When using AI dispatchers, your prompts and context may be sent to third-party AI providers (e.g., OpenRouter). Please review the privacy policies of these providers. We recommend against sending highly sensitive personal or proprietary information to AI models.

## Incident Response Plan

In the event of a security incident (e.g., exposed API key, system compromise due to a vulnerability in the dotfiles):

1.  **Isolate:** Immediately stop using the compromised system or revoke the compromised credentials.
2.  **Assess:** Determine the scope and impact of the incident.
3.  **Remediate:** Fix the vulnerability, rotate affected credentials, and restore from a clean backup if necessary.
4.  **Communicate:** If the vulnerability affects others, communicate transparently with the community.
5.  **Learn:** Document the incident and implement measures to prevent recurrence.
