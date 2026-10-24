[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (git rev-parse --show-toplevel).Trim()
if (-not $repositoryRoot) {
    throw 'Run this script from inside the Money MM Git repository.'
}

Set-Location -LiteralPath $repositoryRoot
git config --local core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) {
    throw 'Could not configure the repository hooks path.'
}

$configuredPath = (git config --local --get core.hooksPath).Trim()
if ($configuredPath -ne '.githooks') {
    throw "Unexpected hooks path: $configuredPath"
}

if (-not (Get-Command gitleaks -ErrorAction SilentlyContinue)) {
    Write-Warning 'Hooks are enabled fail-closed, but gitleaks is not installed or not on PATH.'
    Write-Host 'Install the pinned version documented in SECURITY.md before committing or pushing.'
    exit 2
}

Write-Host "Git hooks enabled: $configuredPath"
gitleaks version

