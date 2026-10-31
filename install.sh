#!/bin/sh
# Installs the no-ai-coauthor git hooks (Linux / macOS / Git Bash).
#
#   Every repository:    curl -fsSL https://raw.githubusercontent.com/N0tMaggi/no-ai-coauthor-hooks/main/install.sh | sh
#   Current repo only:   curl -fsSL https://raw.githubusercontent.com/N0tMaggi/no-ai-coauthor-hooks/main/install.sh | sh -s -- --local
#
# Global mode uses the global core.hooksPath if one is already set, otherwise ~/.git-hooks.
# Local mode installs into the current repository's hooks folder.
# Existing hooks with the same name are backed up before they are replaced.

set -eu

RAW_URL="https://raw.githubusercontent.com/N0tMaggi/no-ai-coauthor-hooks/main/hooks"
HOOKS="commit-msg pre-push"

usage() {
    echo "usage: install.sh [--global | --local]"
    echo "  --global  install for every repository on this machine (default)"
    echo "  --local   install only for the git repository you are in"
}

mode=global
for arg in "$@"; do
    case $arg in
        -g|--global) mode=global ;;
        -l|--local) mode=local ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown option $arg" >&2; usage >&2; exit 1 ;;
    esac
done

if ! command -v git >/dev/null 2>&1; then
    echo "error: git is not installed" >&2
    exit 1
fi

# shows paths in the home folder as ~/... (git on Windows reports C:/Users/... instead of /c/Users/...)
home_win=$(cygpath -m "$HOME" 2>/dev/null || echo "$HOME")
pretty() {
    case $1 in
        "$HOME"/*) echo "~${1#"$HOME"}" ;;
        "$home_win"/*) echo "~${1#"$home_win"}" ;;
        *) echo "$1" ;;
    esac
}

if [ "$mode" = local ]; then
    git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || {
        echo "error: not inside a git repository. cd into your repo first, or install globally without --local" >&2
        exit 1
    }
    hooks_dir="$git_dir/hooks"
else
    hooks_dir=$(git config --global --get core.hooksPath || true)
    [ -n "$hooks_dir" ] || hooks_dir="$HOME/.git-hooks"
    # git doesn't expand ~ in core.hooksPath for us here
    case "$hooks_dir" in
        "~"*) hooks_dir="$HOME${hooks_dir#\~}" ;;
    esac
fi

mkdir -p "$hooks_dir"

# when run from a clone, use the local files instead of downloading them
script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")
[ -n "$script_dir" ] && [ -f "$script_dir/install.sh" ] && [ -f "$script_dir/hooks/commit-msg" ] || script_dir=""

for hook in $HOOKS; do
    target="$hooks_dir/$hook"

    if [ -f "$target" ] && ! grep -q "AI Co-Author" "$target"; then
        backup="$target.bak.$(date +%Y%m%d%H%M%S)"
        mv "$target" "$backup"
        echo "Backed up existing $hook hook to $(pretty "$backup")"
    fi

    if [ -n "$script_dir" ]; then
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
    echo "Installed $hook -> $(pretty "$target")"
done

echo ""
if [ "$mode" = local ]; then
    # a global core.hooksPath would make git ignore this repository's hooks folder
    if git config --global --get core.hooksPath >/dev/null 2>&1; then
        git config --local core.hooksPath "$hooks_dir"
        echo "Set core.hooksPath for this repository, so it uses its own hooks folder."
    fi
    echo "Done. AI Co-Authored-By trailers are now blocked in this repository."
else
    git config --global core.hooksPath "$hooks_dir"
    echo "Done. core.hooksPath = $(pretty "$hooks_dir")"
    echo "AI Co-Authored-By trailers are now blocked in every repository."
fi
