$ErrorActionPreference = "Stop"

param(
  [string]$OutFile = "kubeconfig-jenkins.yaml"
)

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { throw "kubectl not found in PATH" }

kubectl config view --raw --minify | Out-File -Encoding ascii $OutFile

$content = Get-Content $OutFile

# If kubeconfig points to 127.0.0.1 (common with Minikube docker driver),
# switch it to host.docker.internal so Jenkins-in-Docker can reach the API server.
$content = $content -replace 'server:\s+https://127\.0\.0\.1:(\d+)', 'server: https://host.docker.internal:$1'

# Add insecure-skip-tls-verify for local Minikube usage from inside Docker.
if (-not ($content -match 'insecure-skip-tls-verify:\s*true')) {
  $out = New-Object System.Collections.Generic.List[string]
  $inserted = $false
  foreach ($line in $content) {
    $out.Add($line)
    if (-not $inserted -and ($line -match '^(\s*)server:\s+')) {
      $indent = $Matches[1]
      $out.Add("${indent}insecure-skip-tls-verify: true")
      $inserted = $true
    }
  }
  $content = $out.ToArray()
}

$content | Set-Content -Encoding ascii $OutFile
Write-Host "Wrote $OutFile"

