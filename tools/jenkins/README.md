# Jenkins (Docker) for this repo

This repo includes a Jenkins controller image (with `docker` CLI + `kubectl`) and a `docker-compose.yml` to run it locally.

## 1) Start Jenkins

From the repo root:

```powershell
docker compose -f tools/jenkins/docker-compose.yml up -d --build
```

Open Jenkins: http://localhost:8080

Get the initial admin password:

```powershell
docker exec -it end-to-end-devops-pipeline-jenkins-1 cat /var/jenkins_home/secrets/initialAdminPassword
```

If your container name differs:

```powershell
docker ps --format "table {{.Names}}\t{{.Image}}"
```

## 2) Create required Jenkins credentials

Jenkins → **Manage Jenkins** → **Credentials**:

1. `dockerhub` (Username with password)
   - Username: Docker Hub username
   - Password: Docker Hub access token (recommended)

2. `kubeconfig` (Secret file)
   - Use a kubeconfig that Jenkins can reach from inside the Jenkins container.

### kubeconfig for Minikube (Docker driver on Windows)

Generate a file from your host:

```powershell
kubectl config view --raw --minify | Out-File -Encoding ascii .\kubeconfig-jenkins.yaml
```

If Jenkins runs in Docker, your kubeconfig may point to `127.0.0.1` (host loopback), which will not work inside the Jenkins container.
Update the `server:` line to Minikube IP:

```powershell
$ip = minikube ip
(Get-Content .\kubeconfig-jenkins.yaml) -replace 'server: https://127\.0\.0\.1:\d+', "server: https://$ip`:8443" |
  Set-Content -Encoding ascii .\kubeconfig-jenkins.yaml
```

Validate:

```powershell
kubectl --kubeconfig .\kubeconfig-jenkins.yaml get nodes
```

Upload `kubeconfig-jenkins.yaml` as the `kubeconfig` secret file credential in Jenkins.

## 3) Create the Pipeline job

Jenkins → **New Item** → **Pipeline**
- Definition: **Pipeline script from SCM**
- SCM: Git
- Script Path: `Jenkinsfile`

Run **Build with Parameters** and set `DOCKER_IMAGE` to your Docker Hub repo, e.g. `myuser/devops-demo-api`.
For non-main builds, disable `PUSH_LATEST` and/or `DEPLOY_TO_K8S` in the build parameters if you don’t want to deploy.
