# Installs the no-ai-coauthor git hooks globally (Windows PowerShell 5.1+ / PowerShell 7).
#
#   irm https://raw.githubusercontent.com/N0tMaggi/no-ai-coauthor-hooks/main/install.ps1 | iex
#
# Uses the global core.hooksPath if one is already set, otherwise ~\.git-hooks.
# Existing hooks with the same name are backed up before they are replaced.
# Git for Windows runs the hooks with its bundled sh, so they work in cmd, PowerShell and IDEs.

$ErrorActionPreference = "Stop"

$rawUrl = "https://raw.githubusercontent.com/N0tMaggi/no-ai-coauthor-hooks/main/hooks"
$hooks = @("commit-msg", "pre-push")

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git is not installed or not on PATH"
    return
}

$hooksDir = git config --global --get core.hooksPath
if (-not $hooksDir) { $hooksDir = Join-Path $HOME ".git-hooks" }
if ($hooksDir.StartsWith("~")) { $hooksDir = $HOME + $hooksDir.Substring(1) }

New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null

# when run from a clone, use the local files instead of downloading them
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $null }

foreach ($hook in $hooks) {
    $target = Join-Path $hooksDir $hook

    if ((Test-Path $target) -and -not (Select-String -Path $target -Pattern "AI Co-Author" -Quiet)) {
        $backup = "$target.bak.$(Get-Date -Format yyyyMMddHHmmss)"
        Move-Item $target $backup
        Write-Host "Backed up existing $hook hook to $backup"
    }

    $localFile = if ($scriptDir) { Join-Path (Join-Path $scriptDir "hooks") $hook } else { $null }
    if ($localFile -and (Test-Path $localFile)) {
        $content = [IO.File]::ReadAllText($localFile)
    } else {
        $content = (Invoke-WebRequest -Uri "$rawUrl/$hook" -UseBasicParsing).Content
        if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
    }

    # git's sh needs LF line endings and no BOM
    [IO.File]::WriteAllText($target, ($content -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
    Write-Host "Installed $hook -> $target"
}

git config --global core.hooksPath ($hooksDir -replace "\\", "/")

Write-Host ""
Write-Host "Done. core.hooksPath = $hooksDir"
Write-Host "Commits and pushes with an AI Co-Authored-By trailer are now blocked in every repository."
