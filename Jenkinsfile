pipeline {
  agent any

  options {
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
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Validate') {
      steps {
        script {
          if (params.DOCKER_IMAGE == null || params.DOCKER_IMAGE.trim().length() == 0) {
            error("DOCKER_IMAGE is empty. Set it to something like: <your-dockerhub-user>/devops-demo-api")
          }
          if (params.DOCKER_IMAGE.contains("YOUR_DOCKERHUB_USER")) {
            error("Replace DOCKER_IMAGE placeholder. Example: myuser/devops-demo-api")
          }
        }
      }
    }

    stage('Tests') {
      when { expression { return params.RUN_TESTS } }
      steps {
        // Run tests as a Docker build stage (no workspace bind-mount required; works with Jenkins-in-Docker).
        // Dockerfile has a `test` target that runs `pytest`.
        script {
          if (isUnix()) {
            sh "docker build --target test ."
          } else {
            bat "docker build --target test ."
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

                kubectl --kubeconfig "\$KUBECONFIG" get ns "${params.K8S_NAMESPACE}" >/dev/null 2>&1 || \
                  kubectl --kubeconfig "\$KUBECONFIG" create ns "${params.K8S_NAMESPACE}"

                kubectl --kubeconfig "\$KUBECONFIG" -n "${params.K8S_NAMESPACE}" apply -f k8s/deployment.yaml
                kubectl --kubeconfig "\$KUBECONFIG" -n "${params.K8S_NAMESPACE}" apply -f k8s/service.yaml

                kubectl --kubeconfig "\$KUBECONFIG" -n "${params.K8S_NAMESPACE}" set image deployment/devops-demo-api devops-demo-api=${params.DOCKER_IMAGE}:${env.IMAGE_TAG}
                kubectl --kubeconfig "\$KUBECONFIG" -n "${params.K8S_NAMESPACE}" rollout status deployment/devops-demo-api --timeout=180s

                kubectl --kubeconfig "\$KUBECONFIG" -n "${params.K8S_NAMESPACE}" get pods,svc -o wide
              """
            } else {
              bat """
                @echo off

                kubectl --kubeconfig "%KUBECONFIG%" get ns "${params.K8S_NAMESPACE}" >nul 2>nul || ^
                  kubectl --kubeconfig "%KUBECONFIG%" create ns "${params.K8S_NAMESPACE}"

                kubectl --kubeconfig "%KUBECONFIG%" -n "${params.K8S_NAMESPACE}" apply -f k8s/deployment.yaml
                kubectl --kubeconfig "%KUBECONFIG%" -n "${params.K8S_NAMESPACE}" apply -f k8s/service.yaml

                kubectl --kubeconfig "%KUBECONFIG%" -n "${params.K8S_NAMESPACE}" set image deployment/devops-demo-api devops-demo-api=${params.DOCKER_IMAGE}:${env.IMAGE_TAG}
                kubectl --kubeconfig "%KUBECONFIG%" -n "${params.K8S_NAMESPACE}" rollout status deployment/devops-demo-api --timeout=180s

                kubectl --kubeconfig "%KUBECONFIG%" -n "${params.K8S_NAMESPACE}" get pods,svc -o wide
              """
            }
          }
        }
      }
    }
  }
}
