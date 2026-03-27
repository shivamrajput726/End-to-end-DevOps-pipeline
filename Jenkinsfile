pipeline {
  agent any

  options {
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'DOCKER_IMAGE', defaultValue: 'shivam726/devops-demo-api', description: 'Docker Hub repo/image')
    booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run unit tests')
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
            error("DOCKER_IMAGE empty hai bhai ❌")
          }
        }
      }
    }

    // 🔥 FIXED LOGIN STAGE
    stage('Login to DockerHub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
          sh 'echo $PASSWORD | docker login -u $USERNAME --password-stdin'
        }
      }
    }

    stage('Build') {
      steps {
        script {
          def gitSha = (env.GIT_COMMIT ?: '').take(7)
          if (!gitSha) { gitSha = 'local' }

          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${gitSha}"
          echo "Building: ${params.DOCKER_IMAGE}:${env.IMAGE_TAG}"

          sh "docker build -t ${params.DOCKER_IMAGE}:${env.IMAGE_TAG} ."
        }
      }
    }

    stage('Push') {
      steps {
        script {
          sh "docker push ${params.DOCKER_IMAGE}:${env.IMAGE_TAG}"
        }
      }
    }

    stage('Tag latest') {
      when { expression { return params.PUSH_LATEST } }
      steps {
        script {
          sh """
            docker tag ${params.DOCKER_IMAGE}:${env.IMAGE_TAG} ${params.DOCKER_IMAGE}:latest
            docker push ${params.DOCKER_IMAGE}:latest
          """
        }
      }
    }

  }
}