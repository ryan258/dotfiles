# Artifact And Log Policy

Runtime artifacts should not create repo review noise.

## Locations

- Durable user data: `~/.config/dotfiles-data/`
- Active system log: `${SYSTEM_LOG_FILE:-~/.config/dotfiles-data/system.log}`
- Dispatcher usage log: `${DISPATCHER_USAGE_LOG:-~/.config/dotfiles-data/dispatcher_usage.log}`
- Transient caches: `~/.cache/dotfiles/`
- Transient run logs, when needed: `~/.cache/dotfiles/logs/`

Repo-local `logs/` should not be used for durable data. It is ignored only as a safety net for accidental runtime output.

## Rotation

`scripts/logs.sh rotate` rotates the system and dispatcher logs through `rotate_log`.

Default behavior:

- Rotate when a log exceeds `DEFAULT_LOG_ROTATE_MAX_BYTES` (`10485760`, 10 MB).
- Keep the five newest rotated copies.
- Leave the active log path in place for daily commands.

## Cleanup

`scripts/logs.sh clean` removes rotated system and dispatcher logs older than 30 days.

Cleanup must not delete user data files such as todos, journals, health logs, spoon logs, credentials, or active logs.
