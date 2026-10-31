#!/bin/sh
# Installs the no-ai-coauthor git hooks globally (Linux / macOS / Git Bash).
#
#   curl -fsSL https://raw.githubusercontent.com/N0tMaggi/no-ai-coauthor-hooks/main/install.sh | sh
#
# Uses the global core.hooksPath if one is already set, otherwise ~/.git-hooks.
# Existing hooks with the same name are backed up before they are replaced.

set -eu

RAW_URL="https://raw.githubusercontent.com/N0tMaggi/no-ai-coauthor-hooks/main/hooks"
HOOKS="commit-msg pre-push"

if ! command -v git >/dev/null 2>&1; then
    echo "error: git is not installed" >&2
    exit 1
fi

hooks_dir=$(git config --global --get core.hooksPath || true)
[ -n "$hooks_dir" ] || hooks_dir="$HOME/.git-hooks"
# git doesn't expand ~ in core.hooksPath for us here
case "$hooks_dir" in
    "~"*) hooks_dir="$HOME${hooks_dir#\~}" ;;
esac

mkdir -p "$hooks_dir"

# when run from a clone, use the local files instead of downloading them
script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")

for hook in $HOOKS; do
    target="$hooks_dir/$hook"

    if [ -f "$target" ] && ! grep -q "AI Co-Author" "$target"; then
        backup="$target.bak.$(date +%Y%m%d%H%M%S)"
        mv "$target" "$backup"
        echo "Backed up existing $hook hook to $backup"
    fi

    if [ -n "$script_dir" ] && [ -f "$script_dir/hooks/$hook" ]; then
        cp "$script_dir/hooks/$hook" "$target"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "$RAW_URL/$hook" -o "$target"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$target" "$RAW_URL/$hook"
    else
        echo "error: neither curl nor wget is installed" >&2
        exit 1
    fi

    chmod +x "$target"
    echo "Installed $hook -> $target"
done

git config --global core.hooksPath "$hooks_dir"

echo ""
echo "Done. core.hooksPath = $hooks_dir"
echo "Commits and pushes with an AI Co-Authored-By trailer are now blocked in every repository."
