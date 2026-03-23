#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() { printf "\n[%s] %s\n" "$(date +'%H:%M:%S')" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

compose() {
  if have docker && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif have docker-compose; then
    docker-compose "$@"
  else
    die "docker compose not found"
  fi
}

load_env() {
  if [[ -f ".env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source ".env"
    set +a
  fi
}

wait_http() {
  local url="$1"
  local tries="${2:-60}"
  local sleep_s="${3:-2}"
  if ! have curl; then
    log "curl not found; skipping readiness wait for $url"
    return 0
  fi
  for _ in $(seq 1 "$tries"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_s"
  done
  die "Timed out waiting for $url"
}

wait_crd() {
  local crd="$1"
  local tries="${2:-60}"
  local sleep_s="${3:-2}"
  for _ in $(seq 1 "$tries"); do
    if kubectl get crd "$crd" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_s"
  done
  die "Timed out waiting for CRD: $crd"
}

aws_up() {
  log "Terraform: provisioning AWS EC2 + k3s"

  have terraform || die "terraform not found"
  have scp || die "scp not found"
  have sed || die "sed not found"

  : "${SSH_KEY_PATH:?Set SSH_KEY_PATH in .env (private key path)}"
  : "${SSH_PUB_KEY_PATH:?Set SSH_PUB_KEY_PATH in .env (public key path)}"

  local tf_dir="infra/terraform/aws-k3s"
  pushd "$tf_dir" >/dev/null

  terraform init

  local ssh_pub
  ssh_pub="$(cat "$SSH_PUB_KEY_PATH")"

  terraform apply -auto-approve \
    -var "aws_region=${AWS_REGION:-us-east-1}" \
    -var "ssh_public_key=$ssh_pub" \
    -var "ssh_cidr=${SSH_CIDR:-0.0.0.0/0}"

  local ip
  ip="$(terraform output -raw public_ip)"

  popd >/dev/null

  log "Fetching kubeconfig from $ip"
  scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "ubuntu@${ip}:/etc/rancher/k3s/k3s.yaml" "./kubeconfig.yaml"

  # Replace server address to use public IP
  sed -i.bak "s/127.0.0.1/${ip}/g" "./kubeconfig.yaml" || true
  rm -f ./kubeconfig.yaml.bak || true

  export KUBECONFIG="$ROOT_DIR/kubeconfig.yaml"
  log "KUBECONFIG set to $KUBECONFIG"
}

main() {
  local use_aws="false"
  if [[ "${1:-}" == "--aws" ]]; then
    use_aws="true"
    shift || true
  fi

  load_env

  have docker || die "docker not found"
  have kubectl || die "kubectl not found"
  have helm || die "helm not found"
  have git || log "git not found; image tag will not use commit SHA"

  : "${DOCKERHUB_USER:?Set DOCKERHUB_USER in .env}"
  : "${DOCKERHUB_TOKEN:?Set DOCKERHUB_TOKEN in .env}"

  export DOCKER_IMAGE="${DOCKER_IMAGE:-${DOCKERHUB_USER}/devops-demo-api}"
  export K8S_NAMESPACE="${K8S_NAMESPACE:-devops-demo}"
  export MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
  export HELM_RELEASE="${HELM_RELEASE:-kube-prometheus-stack}"

  if [[ "$use_aws" == "true" ]]; then
    aws_up
  fi

  log "Starting SonarQube"
  compose -f tools/sonarqube/docker-compose.yml up -d
  wait_http "http://localhost:9000/api/system/status" 90 2

  log "Starting Jenkins"
  compose -f tools/jenkins/docker-compose.yml up -d --build
  wait_http "http://localhost:8080/login" 90 2
  log "Jenkins initial admin password (first run only):"
  compose -f tools/jenkins/docker-compose.yml exec -T jenkins cat /var/jenkins_home/secrets/initialAdminPassword || true

  log "Docker login"
  echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin

  local sha tag
  sha="$(git rev-parse --short HEAD 2>/dev/null || true)"
  tag="${TAG:-${sha:-local}-$(date +%Y%m%d%H%M%S)}"

  log "Building image: ${DOCKER_IMAGE}:${tag}"
  docker build -t "${DOCKER_IMAGE}:${tag}" .

  log "Pushing image: ${DOCKER_IMAGE}:${tag}"
  docker push "${DOCKER_IMAGE}:${tag}"

  log "Deploying app manifests (namespace/deploy/service)"
  kubectl apply -f k8s/00-namespace.yaml
  kubectl apply -f k8s/10-deployment.yaml
  kubectl apply -f k8s/20-service.yaml

  log "Installing monitoring stack (Prometheus + Grafana)"
  kubectl create namespace "$MONITORING_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update
  helm upgrade --install "$HELM_RELEASE" prometheus-community/kube-prometheus-stack \
    --namespace "$MONITORING_NAMESPACE" \
    -f monitoring/kube-prometheus-stack-values.yaml

  log "Applying ServiceMonitor"
  wait_crd "servicemonitors.monitoring.coreos.com" 90 2
  kubectl apply -f k8s/30-servicemonitor.yaml

  log "Updating deployment image (rolling update)"
  kubectl -n "$K8S_NAMESPACE" set image deployment/devops-demo-api devops-demo-api="${DOCKER_IMAGE}:${tag}"
  kubectl -n "$K8S_NAMESPACE" rollout status deployment/devops-demo-api --timeout=180s

  log "Done"
  echo "Jenkins:   http://localhost:8080"
  echo "SonarQube: http://localhost:9000"
  echo "Grafana:   kubectl -n ${MONITORING_NAMESPACE} port-forward svc/${HELM_RELEASE}-grafana 3000:80"
}

main "$@"
