$ErrorActionPreference = "Stop"

function Write-Log($msg) {
  $ts = Get-Date -Format "HH:mm:ss"
  Write-Host "`n[$ts] $msg"
}

function Load-DotEnv {
  param([string]$Path = ".env")
  if (!(Test-Path $Path)) { return }
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith("#")) { return }
    $parts = $line.Split("=", 2)
    if ($parts.Count -ne 2) { return }
    $name = $parts[0].Trim()
    $value = $parts[1].Trim()
    if ($name.Length -gt 0) { Set-Item -Path "Env:$name" -Value $value }
  }
}

function Compose {
  param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
  & docker compose @Args
}

function Wait-Http {
  param([string]$Url, [int]$Tries = 90, [int]$SleepSeconds = 2)
  for ($i = 0; $i -lt $Tries; $i++) {
    try {
      Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 2 | Out-Null
      return
    } catch {
      Start-Sleep -Seconds $SleepSeconds
    }
  }
  throw "Timed out waiting for $Url"
}

function Wait-Crd {
  param([string]$Name, [int]$Tries = 90, [int]$SleepSeconds = 2)
  for ($i = 0; $i -lt $Tries; $i++) {
    try {
      kubectl get crd $Name | Out-Null
      return
    } catch {
      Start-Sleep -Seconds $SleepSeconds
    }
  }
  throw "Timed out waiting for CRD: $Name"
}

param(
  [switch]$Aws
)

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Load-DotEnv

if (-not $env:DOCKERHUB_USER) { throw "Set DOCKERHUB_USER in .env" }
if (-not $env:DOCKERHUB_TOKEN) { throw "Set DOCKERHUB_TOKEN in .env" }

if (-not $env:DOCKER_IMAGE) { $env:DOCKER_IMAGE = "$($env:DOCKERHUB_USER)/devops-demo-api" }
if (-not $env:K8S_NAMESPACE) { $env:K8S_NAMESPACE = "devops-demo" }
if (-not $env:MONITORING_NAMESPACE) { $env:MONITORING_NAMESPACE = "monitoring" }
if (-not $env:HELM_RELEASE) { $env:HELM_RELEASE = "kube-prometheus-stack" }

if ($Aws) {
  if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) { throw "terraform not found" }
  if (-not $env:SSH_KEY_PATH) { throw "Set SSH_KEY_PATH in .env" }
  if (-not $env:SSH_PUB_KEY_PATH) { throw "Set SSH_PUB_KEY_PATH in .env" }

  Write-Log "Terraform: provisioning AWS EC2 + k3s"
  Push-Location "infra/terraform/aws-k3s"
  terraform init
  $sshPub = Get-Content $env:SSH_PUB_KEY_PATH -Raw
  $awsRegion = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }
  $sshCidr = if ($env:SSH_CIDR) { $env:SSH_CIDR } else { "0.0.0.0/0" }
  terraform apply -auto-approve -var "aws_region=$awsRegion" -var "ssh_public_key=$sshPub" -var "ssh_cidr=$sshCidr"
  $ip = terraform output -raw public_ip
  Pop-Location

  Write-Log "Fetching kubeconfig from $ip"
  scp -i $env:SSH_KEY_PATH -o StrictHostKeyChecking=no ("ubuntu@{0}:/etc/rancher/k3s/k3s.yaml" -f $ip) ".\kubeconfig.yaml"
  (Get-Content .\kubeconfig.yaml) -replace "127.0.0.1", $ip | Set-Content .\kubeconfig.yaml
  $env:KUBECONFIG = Join-Path $Root "kubeconfig.yaml"
  Write-Log "KUBECONFIG set to $env:KUBECONFIG"
}

Write-Log "Starting SonarQube"
Compose -f tools/sonarqube/docker-compose.yml up -d
Wait-Http "http://localhost:9000/api/system/status"

Write-Log "Starting Jenkins"
Compose -f tools/jenkins/docker-compose.yml up -d --build
Wait-Http "http://localhost:8080/login"
Write-Log "Jenkins initial admin password (first run only):"
try { docker compose -f tools/jenkins/docker-compose.yml exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword } catch {}

Write-Log "Docker login"
$env:DOCKERHUB_TOKEN | docker login -u $env:DOCKERHUB_USER --password-stdin | Out-Null

$sha = ""
try { $sha = (git rev-parse --short HEAD).Trim() } catch {}
if (-not $sha) { $sha = "local" }
$tag = if ($env:TAG) { $env:TAG } else { "{0}-{1}" -f $sha, (Get-Date -Format "yyyyMMddHHmmss") }

Write-Log "Building image: $($env:DOCKER_IMAGE):$tag"
docker build -t "$($env:DOCKER_IMAGE):$tag" .

Write-Log "Pushing image: $($env:DOCKER_IMAGE):$tag"
docker push "$($env:DOCKER_IMAGE):$tag"

Write-Log "Deploying app manifests (namespace/deploy/service)"
kubectl apply -f .\k8s\00-namespace.yaml
kubectl apply -f .\k8s\10-deployment.yaml
kubectl apply -f .\k8s\20-service.yaml

Write-Log "Installing monitoring stack (Prometheus + Grafana)"
kubectl create namespace $env:MONITORING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>$null
helm repo update
helm upgrade --install $env:HELM_RELEASE prometheus-community/kube-prometheus-stack `
  --namespace $env:MONITORING_NAMESPACE `
  -f .\monitoring\kube-prometheus-stack-values.yaml

Write-Log "Applying ServiceMonitor"
Wait-Crd "servicemonitors.monitoring.coreos.com"
kubectl apply -f .\k8s\30-servicemonitor.yaml

Write-Log "Updating deployment image (rolling update)"
kubectl -n $env:K8S_NAMESPACE set image deployment/devops-demo-api devops-demo-api="$($env:DOCKER_IMAGE):$tag"
kubectl -n $env:K8S_NAMESPACE rollout status deployment/devops-demo-api --timeout=180s

Write-Log "Done"
Write-Host "Jenkins:   http://localhost:8080"
Write-Host "SonarQube: http://localhost:9000"
Write-Host "Grafana:   kubectl -n $($env:MONITORING_NAMESPACE) port-forward svc/$($env:HELM_RELEASE)-grafana 3000:80"
