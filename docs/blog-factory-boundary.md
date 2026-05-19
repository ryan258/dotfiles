# Blog Factory Boundary

Blog Factory is now an optional sibling product.

Default checkout:

```bash
~/Projects/blog-factory
```

Override:

```bash
export BLOG_FACTORY_HOME="$HOME/Projects/blog-factory"
```

## Dotfiles Owns

- `scripts/blog.sh` compatibility wrapper.
- `scripts/blog_recent_content.sh` compatibility wrapper.
- `blog` and `blog-recent` aliases.
- Daily-loop fallback behavior when Blog Factory is absent.
- `BLOG_DIR` and `BLOG_STATUS_DIR` integration points for `startday` and `goodevening`.

## Blog Factory Owns

- Blog CLI implementation.
- Recent-content helper implementation.
- Blog shell libraries.
- Blog validation helper.
- Blog-specific tests, docs, dependency notes, and config examples.

## Degradation Contract

Direct commands print a short setup message if Blog Factory is missing:

```text
Blog Factory is unavailable. Expected sibling repo: ...
```

Daily-loop calls set `BLOG_FACTORY_DAILY_HOOK=true`, so missing Blog Factory produces only the existing concise daily fallback unless `BLOG_FACTORY_WRAPPER_VERBOSE=true` is set.

## Rollback

Restore the moved implementation files from git and point `scripts/blog.sh` / `scripts/blog_recent_content.sh` back to the in-repo implementation. Keep the wrappers until the sibling repo is known-good.
