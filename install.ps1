# Installs the no-ai-coauthor git hooks (Windows PowerShell 5.1+ / PowerShell 7).
#
#   Every repository:   irm https://raw.githubusercontent.com/N0tMaggi/no-ai-coauthor-hooks/main/install.ps1 | iex
#   Current repo only:  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/N0tMaggi/no-ai-coauthor-hooks/main/install.ps1))) -Local
#
# Global mode uses the global core.hooksPath if one is already set, otherwise ~\.git-hooks.
# Local mode installs into the current repository's hooks folder.
# Existing hooks with the same name are backed up before they are replaced.
# Git for Windows runs the hooks with its bundled sh, so they work in cmd, PowerShell and IDEs.

param([switch]$Local)

$ErrorActionPreference = "Stop"

$rawUrl = "https://raw.githubusercontent.com/N0tMaggi/no-ai-coauthor-hooks/main/hooks"
$hooks = @("commit-msg", "pre-push")

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git is not installed or not on PATH"
    return
}

# shows paths in the home folder as ~\...
function Format-Path([string]$path) {
    $full = [IO.Path]::GetFullPath($path)
    if ($full.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { return "~" + $full.Substring($HOME.Length) }
    return $full
}

if ($Local) {
    # git's "not a git repository" on stderr must not trip $ErrorActionPreference = Stop
    $gitDir = & { $ErrorActionPreference = "Continue"; git rev-parse --absolute-git-dir 2>$null }
    if ($LASTEXITCODE -ne 0 -or -not $gitDir) {
        Write-Error "Not inside a git repository. cd into your repo first, or install globally without -Local."
        return
    }
    $hooksDir = Join-Path $gitDir "hooks"
} else {
    $hooksDir = git config --global --get core.hooksPath
    if (-not $hooksDir) { $hooksDir = Join-Path $HOME ".git-hooks" }
    if ($hooksDir.StartsWith("~")) { $hooksDir = $HOME + $hooksDir.Substring(1) }
}

New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null

# when run from a clone, use the local files instead of downloading them
$scriptDir = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "hooks\commit-msg"))) { $PSScriptRoot } else { $null }

foreach ($hook in $hooks) {
    $target = Join-Path $hooksDir $hook

    if ((Test-Path $target) -and -not (Select-String -Path $target -Pattern "AI Co-Author" -Quiet)) {
        $backup = "$target.bak.$(Get-Date -Format yyyyMMddHHmmss)"
        Move-Item $target $backup
        Write-Host "Backed up existing $hook hook to $(Format-Path $backup)"
    }

    if ($scriptDir) {
        $content = [IO.File]::ReadAllText((Join-Path (Join-Path $scriptDir "hooks") $hook))
    } else {
        $content = (Invoke-WebRequest -Uri "$rawUrl/$hook" -UseBasicParsing).Content
        if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
    }

    # git's sh needs LF line endings and no BOM
    [IO.File]::WriteAllText($target, ($content -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
    Write-Host "Installed $hook -> $(Format-Path $target)"
}

Write-Host ""
if ($Local) {
    # a global core.hooksPath would make git ignore this repository's hooks folder
    if (git config --global --get core.hooksPath) {
        git config --local core.hooksPath ($hooksDir -replace "\\", "/")
        Write-Host "Set core.hooksPath for this repository, so it uses its own hooks folder."
    }
    Write-Host "Done. AI Co-Authored-By trailers are now blocked in this repository."
} else {
    git config --global core.hooksPath ($hooksDir -replace "\\", "/")
    Write-Host "Done. core.hooksPath = $(Format-Path $hooksDir)"
    Write-Host "AI Co-Authored-By trailers are now blocked in every repository."
}
