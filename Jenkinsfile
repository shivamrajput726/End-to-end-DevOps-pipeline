pipeline {
  agent any

  parameters {
    string(name: 'DOCKER_IMAGE', defaultValue: 'shivamrajput726/devops-demo-api', description: 'Docker image')
  }

  environment {
    IMAGE_TAG = "latest"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build') {
      steps {
        sh "docker build -t ${params.DOCKER_IMAGE}:${env.IMAGE_TAG} ."
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

  }
}
