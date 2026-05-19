# External Dependencies

Generated: May 18, 2026

## Credential-Like Configuration Keys

These keys were detected from `.env.example` and should stay out of generated logs.

- `CARGO_REGISTRY_TOKEN`
- `GOOGLE_DRIVE_CLIENT_SECRET`
- `GOOGLE_HEALTH_CLIENT_SECRET`
- `NPM_TOKEN`
- `OPENROUTER_API_KEY`
- `TWINE_PASSWORD`

## Configuration Identifiers Not Flagged As Secrets

Client IDs and usernames may also appear in `.env.example`. They identify configured integrations, but this inventory keeps them out of the credential-like list unless the key name contains `KEY`, `TOKEN`, `SECRET`, or `PASSWORD`.

## Optional External Services

- OpenRouter for AI dispatchers and coach framing.
- GitHub for repo activity summaries.
- Fitbit for wearable health context.
- Google Drive for focus-related document evidence.
- Google Calendar for schedule context.
- Obsidian observer as an optional sibling product.
- Cyborg agent as an optional sibling product.
- Blog Factory as an optional sibling product.
- AI Staff HQ as an optional submodule or sibling checkout.

## Phase 0 Note

This file records integration surface only. It does not validate credentials or call external services.
