.PHONY: venv install test lint run docker-build docker-run \
	sonarqube-up sonarqube-down jenkins-up jenkins-down services-up services-down \
	docker-login docker-push k8s-apply monitoring-up run-all run-all-aws

VENV ?= .venv
PY ?= $(VENV)/Scripts/python
PIP ?= $(VENV)/Scripts/pip

DOCKERHUB_USER ?=
DOCKERHUB_TOKEN ?=
DOCKER_IMAGE ?= $(DOCKERHUB_USER)/devops-demo-api
TAG ?= local
K8S_NAMESPACE ?= devops-demo
MONITORING_NAMESPACE ?= monitoring
HELM_RELEASE ?= kube-prometheus-stack

venv:
	python -m venv $(VENV)

install: venv
	$(PIP) install -r requirements.txt -r requirements-dev.txt

test:
	$(PY) -m pytest --cov=app --cov-report=term-missing --cov-report=xml:coverage.xml

lint:
	$(PY) -m ruff check .

run:
	$(PY) -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

docker-build:
	docker build -t devops-demo-api:local .

docker-run:
	docker run --rm -p 8000:8000 devops-demo-api:local

sonarqube-up:
	docker compose -f tools/sonarqube/docker-compose.yml up -d

sonarqube-down:
	docker compose -f tools/sonarqube/docker-compose.yml down

jenkins-up:
	docker compose -f tools/jenkins/docker-compose.yml up -d --build

jenkins-down:
	docker compose -f tools/jenkins/docker-compose.yml down

services-up: sonarqube-up jenkins-up

services-down: jenkins-down sonarqube-down

docker-login:
	@test -n "$(DOCKERHUB_USER)" || (echo "Set DOCKERHUB_USER" && exit 1)
	@test -n "$(DOCKERHUB_TOKEN)" || (echo "Set DOCKERHUB_TOKEN" && exit 1)
	@echo "$(DOCKERHUB_TOKEN)" | docker login -u "$(DOCKERHUB_USER)" --password-stdin

docker-push: docker-login
	@test -n "$(DOCKER_IMAGE)" || (echo "Set DOCKER_IMAGE" && exit 1)
	docker build -t "$(DOCKER_IMAGE):$(TAG)" .
	docker push "$(DOCKER_IMAGE):$(TAG)"

k8s-apply:
	kubectl apply -f k8s/00-namespace.yaml
	kubectl apply -f k8s/10-deployment.yaml
	kubectl apply -f k8s/20-service.yaml
	kubectl -n "$(K8S_NAMESPACE)" set image deployment/devops-demo-api devops-demo-api="$(DOCKER_IMAGE):$(TAG)"
	kubectl -n "$(K8S_NAMESPACE)" rollout status deployment/devops-demo-api --timeout=180s

monitoring-up:
	kubectl create namespace "$(MONITORING_NAMESPACE)" --dry-run=client -o yaml | kubectl apply -f -
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
	helm repo update
	helm upgrade --install "$(HELM_RELEASE)" prometheus-community/kube-prometheus-stack \
		--namespace "$(MONITORING_NAMESPACE)" \
		-f monitoring/kube-prometheus-stack-values.yaml
	kubectl apply -f k8s/30-servicemonitor.yaml

run-all:
	bash scripts/run-all.sh

run-all-aws:
	bash scripts/run-all.sh --aws
