pipeline {
  agent any

  options {
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'DOCKER_IMAGE', defaultValue: 'shivamrajput726/devops-demo-api', description: 'Docker Hub repo/image')
    booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run tests')
    booleanParam(name: 'PUSH_LATEST', defaultValue: true, description: 'Push latest tag')
    booleanParam(name: 'DEPLOY_TO_K8S', defaultValue: true, description: 'Deploy to Kubernetes')
    string(name: 'K8S_NAMESPACE', defaultValue: 'devops-demo', description: 'Namespace')
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
            error("DOCKER_IMAGE empty hai")
          }
        }
      }
    }

    stage('Build') {
      steps {
        script {
          def gitSha = (env.GIT_COMMIT ?: '').take(7)
          if (!gitSha) { gitSha = 'local' }

          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${gitSha}"

          sh "docker build -t ${params.DOCKER_IMAGE}:${env.IMAGE_TAG} ."
        }
      }
    }

    stage('Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
          sh """
            echo "$PASS" | docker login -u "$USER" --password-stdin
            docker push ${params.DOCKER_IMAGE}:${env.IMAGE_TAG}
          """
        }
      }
    }

    stage('Deploy') {
      when { expression { return params.DEPLOY_TO_K8S } }
      steps {
        withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
          sh """
            kubectl --kubeconfig=$KUBECONFIG apply -f k8s/deployment.yaml
            kubectl --kubeconfig=$KUBECONFIG apply -f k8s/service.yaml
          """
        }
      }
    }

  }
}
