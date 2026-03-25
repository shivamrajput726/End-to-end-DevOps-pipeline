pipeline {
  agent any

  // Cross-platform helpers: use `sh` on Linux agents and `bat` on Windows agents.
  // (Jenkins-in-Docker typically runs Linux agents, but this keeps the pipeline portable.)
  // Note: `bat(returnStdout: true)` includes extra newlines; we `.trim()` outputs where needed.
  // These helpers are available inside `script {}` blocks.

  options {
    timestamps()
    ansiColor('xterm')
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'DOCKER_IMAGE', defaultValue: 'YOUR_DOCKERHUB_USER/devops-demo-api', description: 'Docker Hub repo/image (no tag). Example: myuser/devops-demo-api')
    booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run unit tests (pytest) before build.')
    booleanParam(name: 'PUSH_LATEST', defaultValue: true, description: 'Also push :latest tag.')
    booleanParam(name: 'DEPLOY_TO_K8S', defaultValue: true, description: 'Deploy to Kubernetes after pushing image.')
    string(name: 'K8S_NAMESPACE', defaultValue: 'devops-demo', description: 'Namespace to deploy into.')
  }

  environment {
    IMAGE_TAG = ''
    KUBECTL_IMAGE = 'bitnami/kubectl:1.30'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Tests') {
      when { expression { return params.RUN_TESTS } }
      steps {
        script {
          if (isUnix()) {
            sh '''
              set -euo pipefail
              docker run --rm -v "$PWD:/src" -w /src python:3.12-slim bash -lc "
                python -m pip install --no-cache-dir --upgrade pip &&
                pip install --no-cache-dir -r requirements.txt -r requirements-dev.txt &&
                pytest
              "
            '''
          } else {
            bat '''
              @echo off
              docker run --rm -v "%CD%:/src" -w /src python:3.12-slim bash -lc "python -m pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir -r requirements.txt -r requirements-dev.txt && pytest"
            '''
          }
        }
      }
    }

    stage('Build') {
      steps {
        script {
          def cmd = { String unixCmd, String winCmd = null ->
            if (isUnix()) {
              sh unixCmd
            } else {
              bat(winCmd ?: unixCmd)
            }
          }

          def gitSha = (env.GIT_COMMIT ?: '').take(7)
          if (!gitSha) { gitSha = 'local' }
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${gitSha}"
          echo "Building: ${params.DOCKER_IMAGE}:${env.IMAGE_TAG}"

          cmd('docker version')
          cmd("docker build -t ${params.DOCKER_IMAGE}:${env.IMAGE_TAG} .")
        }
      }
    }

    stage('Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
          script {
            if (isUnix()) {
              sh """
                set -euo pipefail
                echo "\$DOCKERHUB_PASS" | docker login -u "\$DOCKERHUB_USER" --password-stdin
                docker push ${params.DOCKER_IMAGE}:${env.IMAGE_TAG}
              """
            } else {
              bat """
                @echo off
                echo %DOCKERHUB_PASS%| docker login -u %DOCKERHUB_USER% --password-stdin
                docker push ${params.DOCKER_IMAGE}:${env.IMAGE_TAG}
              """
            }
          }
        }
      }
    }

    stage('Tag latest') {
      when { expression { return params.PUSH_LATEST } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
          script {
            if (isUnix()) {
              sh """
                set -euo pipefail
                echo "\$DOCKERHUB_PASS" | docker login -u "\$DOCKERHUB_USER" --password-stdin
                docker tag ${params.DOCKER_IMAGE}:${env.IMAGE_TAG} ${params.DOCKER_IMAGE}:latest
                docker push ${params.DOCKER_IMAGE}:latest
              """
            } else {
              bat """
                @echo off
                echo %DOCKERHUB_PASS%| docker login -u %DOCKERHUB_USER% --password-stdin
                docker tag ${params.DOCKER_IMAGE}:${env.IMAGE_TAG} ${params.DOCKER_IMAGE}:latest
                docker push ${params.DOCKER_IMAGE}:latest
              """
            }
          }
        }
      }
    }

    stage('Deploy to Kubernetes') {
      when { expression { return params.DEPLOY_TO_K8S } }
      steps {
        withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
          script {
            if (isUnix()) {
              sh """
                set -euo pipefail

                # Use kubectl via a container so the agent doesn't need kubectl installed.
                docker run --rm -v "\$KUBECONFIG:/kubeconfig:ro" ${env.KUBECTL_IMAGE} \
                  kubectl --kubeconfig /kubeconfig get ns "${params.K8S_NAMESPACE}" >/dev/null 2>&1 || \
                docker run --rm -v "\$KUBECONFIG:/kubeconfig:ro" ${env.KUBECTL_IMAGE} \
                  kubectl --kubeconfig /kubeconfig create ns "${params.K8S_NAMESPACE}"

                docker run --rm -v "\$KUBECONFIG:/kubeconfig:ro" -v "\$PWD:/work" -w /work ${env.KUBECTL_IMAGE} \
                  kubectl --kubeconfig /kubeconfig -n "${params.K8S_NAMESPACE}" apply -f k8s/deployment.yaml
                docker run --rm -v "\$KUBECONFIG:/kubeconfig:ro" -v "\$PWD:/work" -w /work ${env.KUBECTL_IMAGE} \
                  kubectl --kubeconfig /kubeconfig -n "${params.K8S_NAMESPACE}" apply -f k8s/service.yaml

                docker run --rm -v "\$KUBECONFIG:/kubeconfig:ro" ${env.KUBECTL_IMAGE} \
                  kubectl --kubeconfig /kubeconfig -n "${params.K8S_NAMESPACE}" set image deployment/devops-demo-api devops-demo-api=${params.DOCKER_IMAGE}:${env.IMAGE_TAG}
                docker run --rm -v "\$KUBECONFIG:/kubeconfig:ro" ${env.KUBECTL_IMAGE} \
                  kubectl --kubeconfig /kubeconfig -n "${params.K8S_NAMESPACE}" rollout status deployment/devops-demo-api --timeout=180s

                docker run --rm -v "\$KUBECONFIG:/kubeconfig:ro" ${env.KUBECTL_IMAGE} \
                  kubectl --kubeconfig /kubeconfig -n "${params.K8S_NAMESPACE}" get pods,svc -o wide
              """
            } else {
              bat """
                @echo off

                docker run --rm -v "%KUBECONFIG%:/kubeconfig:ro" ${env.KUBECTL_IMAGE} ^
                  kubectl --kubeconfig /kubeconfig get ns "${params.K8S_NAMESPACE}" >nul 2>nul || ^
                docker run --rm -v "%KUBECONFIG%:/kubeconfig:ro" ${env.KUBECTL_IMAGE} ^
                  kubectl --kubeconfig /kubeconfig create ns "${params.K8S_NAMESPACE}"

                docker run --rm -v "%KUBECONFIG%:/kubeconfig:ro" -v "%CD%:/work" -w /work ${env.KUBECTL_IMAGE} ^
                  kubectl --kubeconfig /kubeconfig -n "${params.K8S_NAMESPACE}" apply -f k8s/deployment.yaml
                docker run --rm -v "%KUBECONFIG%:/kubeconfig:ro" -v "%CD%:/work" -w /work ${env.KUBECTL_IMAGE} ^
                  kubectl --kubeconfig /kubeconfig -n "${params.K8S_NAMESPACE}" apply -f k8s/service.yaml

                docker run --rm -v "%KUBECONFIG%:/kubeconfig:ro" ${env.KUBECTL_IMAGE} ^
                  kubectl --kubeconfig /kubeconfig -n "${params.K8S_NAMESPACE}" set image deployment/devops-demo-api devops-demo-api=${params.DOCKER_IMAGE}:${env.IMAGE_TAG}
                docker run --rm -v "%KUBECONFIG%:/kubeconfig:ro" ${env.KUBECTL_IMAGE} ^
                  kubectl --kubeconfig /kubeconfig -n "${params.K8S_NAMESPACE}" rollout status deployment/devops-demo-api --timeout=180s

                docker run --rm -v "%KUBECONFIG%:/kubeconfig:ro" ${env.KUBECTL_IMAGE} ^
                  kubectl --kubeconfig /kubeconfig -n "${params.K8S_NAMESPACE}" get pods,svc -o wide
              """
            }
          }
        }
      }
    }
  }
}
