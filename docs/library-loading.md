# Library Loading Strategy

The root dotfiles repo uses explicit caller-owned library loading.

## Decision

`common.sh` bootstrapping `file_ops.sh` and `config.sh` is transitional compatibility, not the permanent pattern.

Do not add new library self-sourcing. When touching callers, move them toward explicit dependencies instead of relying on `common.sh` to repair the environment.

## Executed Scripts

Executed scripts use strict mode and source dependencies in this order when they need the standard stack:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/date_utils.sh"
```

Daily-loop scripts may use `scripts/lib/loader.sh` where it already provides the stable shared stack.

## Sourced Libraries

Sourced libraries must not use `set -euo pipefail` and must not `exit`.

They should declare expected inputs in the header or fail explicitly when a required function or variable is missing. Callers are responsible for sourcing dependencies in the correct order.

## Compatibility Exception

`scripts/lib/common.sh` may continue to bootstrap `file_ops.sh` and `config.sh` until existing callers are migrated. New code should not depend on that bootstrap.
