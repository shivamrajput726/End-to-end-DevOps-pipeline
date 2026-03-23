$ErrorActionPreference = "Stop"

param(
  [Parameter(Mandatory=$true)][string]$RepoUrl
)

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git not found" }

if (!(Test-Path ".git")) {
  git init
}

git branch -M main

try {
  git remote get-url origin | Out-Null
  git remote set-url origin $RepoUrl
} catch {
  git remote add origin $RepoUrl
}

git add -A

$hasHead = $true
try { git rev-parse --verify HEAD | Out-Null } catch { $hasHead = $false }

if ($hasHead) {
  git diff --cached --quiet
  if ($LASTEXITCODE -ne 0) {
    git commit -m "Initial DevOps pipeline setup"
  }
} else {
  git commit -m "Initial DevOps pipeline setup"
}

git push -u origin main
Write-Host "Done: pushed to origin main"

