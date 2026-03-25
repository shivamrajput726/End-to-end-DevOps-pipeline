# Jenkins (Docker) for this repo

This repo includes a Jenkins controller image (with `docker` CLI and `kubectl`) and a `docker-compose.yml` to run it locally.

## 1) Start Jenkins

From the repo root:

```powershell
docker compose -f tools/jenkins/docker-compose.yml up -d --build
```

Open Jenkins: `http://localhost:8080`

Get the initial admin password (first run only):

```powershell
docker ps --format "table {{.Names}}\t{{.Image}}"
docker exec -it <jenkins_container_name> cat /var/jenkins_home/secrets/initialAdminPassword
```

## 2) Create required Jenkins credentials

Jenkins -> **Manage Jenkins** -> **Credentials**:

1) `dockerhub` (Username with password)
- Username: Docker Hub username
- Password: Docker Hub access token (recommended)

2) `kubeconfig` (Secret file)
- Upload a kubeconfig that Jenkins can use from inside the Jenkins container.

### kubeconfig for Minikube (Docker driver on Windows)

Generate a kubeconfig file for Jenkins-in-Docker from your host:

```powershell
cd "C:\Users\shiva\OneDrive\Desktop\End-to-end DevOps pipeline"
.\scripts\kubeconfig-jenkins.ps1 -OutFile .\kubeconfig-jenkins.yaml
kubectl --kubeconfig .\kubeconfig-jenkins.yaml get nodes
```

Notes:
- The script replaces `127.0.0.1:<port>` with `host.docker.internal:<port>` so the Jenkins container can reach the Kubernetes API server.
- It sets `insecure-skip-tls-verify: true` for local/dev convenience. Do not use this kubeconfig for production clusters.

Upload `kubeconfig-jenkins.yaml` as the `kubeconfig` secret file credential in Jenkins.

## 3) Create the Pipeline job

Jenkins -> **New Item** -> **Pipeline**
- Definition: **Pipeline script from SCM**
- SCM: Git
- Script Path: `Jenkinsfile`

Run **Build with Parameters** and set `DOCKER_IMAGE` to your Docker Hub repo, e.g. `myuser/devops-demo-api`.

