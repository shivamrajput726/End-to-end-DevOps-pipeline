# End-to-end DevOps Pipeline (FastAPI + Jenkins + Docker + Kubernetes + Terraform)

Production-leaning reference project that demonstrates:
- A simple **FastAPI** REST API with tests and Prometheus metrics
- A **Jenkins** CI/CD pipeline with **SonarQube** code analysis and **Trivy** security scanning
- **Docker** image build + push to **Docker Hub**
- **Kubernetes** Deployment/Service with rolling updates
- **Terraform** to provision an AWS **EC2** instance running a single-node **k3s** Kubernetes cluster
- **Prometheus + Grafana** monitoring via `kube-prometheus-stack`

## Architecture

```mermaid
flowchart LR
  Dev[Developer] -->|git push| GH[GitHub Repo]
  GH -->|webhook / poll| J[Jenkins Pipeline]
  J -->|tests + coverage| UT[Pytest]
  J -->|code analysis| SQ[SonarQube]
  J -->|security scan| TV[Trivy]
  J -->|build| DI[Docker Image]
  DI -->|push| DH[(Docker Hub)]
  J -->|kubectl set image| K8S[Kubernetes (k3s/EKS)]
  K8S --> SVC[Service]
  K8S --> PODS[Pods (RollingUpdate)]
  PODS -->|/metrics| PR[Prometheus]
  PR --> GF[Grafana Dashboards]
```

## Repo layout

- `app/` FastAPI application
- `tests/` unit/API tests (pytest)
- `Dockerfile` container build
- `Jenkinsfile` CI/CD pipeline
- `k8s/` Kubernetes manifests (Deployment/Service/ServiceMonitor)
- `infra/terraform/aws-k3s/` Terraform: EC2 + k3s bootstrap
- `monitoring/` Prometheus + Grafana (Helm)
- `tools/sonarqube/` local SonarQube (Docker Compose)

## 1) Run the app locally (Windows-friendly)

```powershell
make install
make test
make run
```

API: `http://localhost:8000`
- `GET /health`
- `GET /api/v1/items`
- `POST /api/v1/items` with JSON: `{"name":"hello"}`
- `GET /metrics`

## 2) Build and run Docker locally

```powershell
make docker-build
make docker-run
```

## 3) SonarQube (local)

Start SonarQube:

```powershell
docker compose -f tools/sonarqube/docker-compose.yml up -d
```

Open `http://localhost:9000` (default login: `admin` / `admin`) and create a project token.

Run a scan locally (example):

```powershell
docker run --rm `
  -e SONAR_HOST_URL="http://host.docker.internal:9000" `
  -e SONAR_LOGIN="YOUR_TOKEN" `
  -v "${PWD}:/usr/src" `
  sonarsource/sonar-scanner-cli
```

## 4) Jenkins CI/CD (GitHub → Tests → SonarQube → Trivy → Docker Hub)

### Quick Jenkins (Docker Compose)

```powershell
docker compose -f tools/jenkins/docker-compose.yml up -d
```

Open `http://localhost:8080` and finish the Jenkins setup wizard.
See `tools/jenkins/README.md` for credential setup and Minikube kubeconfig tips.

### Jenkins prerequisites (agent)

This pipeline runs tooling via Docker containers, so the agent mainly needs:
- `docker` (daemon + CLI)
- access to the Docker socket (`/var/run/docker.sock`)

### Jenkins credentials

Create these credentials in Jenkins:
- `dockerhub` (Username/Password) for Docker Hub push
- `kubeconfig` (Secret file) if using the optional deploy stage

### SonarQube in Jenkins

- Install the **SonarQube Scanner for Jenkins** plugin.
- Configure a SonarQube server in **Manage Jenkins → System** with the name `sonarqube`.

### Create the Pipeline job

- Create a **Pipeline** (or Multibranch Pipeline) job pointing at this GitHub repo.
- In the build parameters, set:
  - `DOCKER_IMAGE`: `YOUR_DOCKERHUB_USER/devops-demo-api`
  - `DEPLOY_TO_K8S`: `true` if you want Jenkins to deploy

## 5) Kubernetes deployment (rolling updates)

Deploy manifests:

```bash
kubectl create namespace devops-demo --dry-run=client -o yaml | kubectl apply -f -
kubectl -n devops-demo apply -f k8s/deployment.yaml
kubectl -n devops-demo apply -f k8s/service.yaml
kubectl -n devops-demo get deploy,svc
```

Update image (example):

```bash
kubectl -n devops-demo set image deployment/devops-demo-api devops-demo-api=YOUR_DOCKERHUB_USER/devops-demo-api:TAG
kubectl -n devops-demo rollout status deployment/devops-demo-api
```

Optional (requires Prometheus Operator / kube-prometheus-stack):

```bash
kubectl apply -f k8s/servicemonitor.yaml
```

Port-forward:

```bash
kubectl -n devops-demo port-forward svc/devops-demo-api 8000:80
curl http://localhost:8000/health
```

## 6) Infrastructure (Terraform: AWS EC2 + k3s)

Provision a single-node k3s cluster on EC2:

```bash
cd infra/terraform/aws-k3s
terraform init
terraform apply -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)" -var="ssh_cidr=YOUR_IP/32"
```

Fetch kubeconfig:

```bash
scp -i ~/.ssh/id_rsa ubuntu@EC2_PUBLIC_IP:/etc/rancher/k3s/k3s.yaml ./kubeconfig.yaml
```

Edit `kubeconfig.yaml` and replace `127.0.0.1` with `EC2_PUBLIC_IP`, then:

```bash
export KUBECONFIG=$PWD/kubeconfig.yaml
kubectl get nodes
```

## 7) Monitoring (Prometheus + Grafana)

See `monitoring/README.md`.

## 8) One-command automation (local or AWS)

Create a `.env` file:

```powershell
Copy-Item .env.example .env
notepad .env
```

Then run end-to-end (starts Jenkins + SonarQube, builds/pushes image, deploys to Kubernetes, installs monitoring):

```powershell
.\scripts\run-all.ps1
```

Provision AWS k3s (Terraform) and then run the same workflow:

```powershell
.\scripts\run-all.ps1 -Aws
```

GitHub automation (init/add remote/commit/push):

```powershell
.\scripts\git-setup.ps1 -RepoUrl https://github.com/<YOUR_GITHUB_USER>/<YOUR_REPO>.git
```

## 9) GitHub Actions (alternative CI/CD)

Workflow file: `.github/workflows/ci-cd.yml`

### Required GitHub Secrets

- `DOCKERHUB_USERNAME`: Docker Hub username
- `DOCKERHUB_TOKEN`: Docker Hub access token

### Optional GitHub Secrets

- `SONAR_HOST_URL`: e.g. `http://host.docker.internal:9000` (or your reachable SonarQube URL)
- `SONAR_TOKEN`: SonarQube token
- `KUBECONFIG_DATA`: base64 of kubeconfig file (enables deploy job)

Create `KUBECONFIG_DATA` (example):

```bash
base64 -w 0 kubeconfig.yaml
```

Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("kubeconfig.yaml"))
```

### Optional GitHub Variables (Repository → Settings → Variables)

- `DOCKER_IMAGE`: override image name (default: `${DOCKERHUB_USERNAME}/devops-demo-api`)
- `K8S_NAMESPACE`: default `devops-demo`
- `TRIVY_FAIL`: set `true` to fail on HIGH/CRITICAL findings
- `ENFORCE_QUALITY_GATE`: set `true` to enforce SonarQube quality gate

## “Run everything” command summary

Local dev:
- `make install && make test && make run`

Docker local:
- `make docker-build && make docker-run`

Kubernetes:
- `kubectl apply -f k8s/`
- `kubectl -n devops-demo port-forward svc/devops-demo-api 8000:80`

Terraform (AWS k3s):
- `cd infra/terraform/aws-k3s && terraform init && terraform apply`
