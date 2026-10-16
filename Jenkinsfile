
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        AWS_REGION = 'ap-south-1'
        BACKEND_IMAGE = 'todo-backend'
        FRONTEND_IMAGE = 'todo-frontend'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Secret Scan') {
            steps {
                bat 'gitleaks detect --source . --redact'
            }
        }

        stage('Test') {
            steps {
                dir('Backend/todo-summary-assistant') {
                    bat 'mvnw.cmd test'
                }
                dir('Frontend/todo') {
                    bat 'npm ci'
                    bat 'npm test -- --watchAll=false'
                }
            }
        }

        stage('Dependency Scan') {
            steps {
                dependencyCheck(
                    odcInstallation: 'OWASP-Dependency-Check'
                )
            }
        }

        stage('Build Images') {
            steps {
                script {
                    env.IMAGE_TAG = env.GIT_COMMIT.take(7)
                }
                bat 'docker build -t %BACKEND_IMAGE%:%IMAGE_TAG% Backend/todo-summary-assistant'
                bat 'docker build -t %FRONTEND_IMAGE%:%IMAGE_TAG% Frontend/todo'
            }
        }

        stage('Image Scan') {
            steps {
                bat 'trivy image --severity HIGH,CRITICAL --exit-code 1 %BACKEND_IMAGE%:%IMAGE_TAG%'
                bat 'trivy image --severity HIGH,CRITICAL --exit-code 1 %FRONTEND_IMAGE%:%IMAGE_TAG%'
            }
        }

        stage('Push to ECR') {
            steps {
                echo 'Configure ECR login and push after creating the AWS registry.'
            }
        }

        stage('Deploy to EC2') {
            steps {
                echo 'Configure automated EC2 deployment after AWS setup.'
            }
        }

        stage('Health Check') {
            steps {
                echo 'Add the deployed application URL after EC2 deployment is configured.'
            }
        }
    }

    post {
        always {
            emailext(
                to: 'YOUR_EMAIL@example.com',
                subject: "${currentBuild.currentResult}: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: """Build status: ${currentBuild.currentResult}
Build URL: ${env.BUILD_URL}
Commit: ${env.GIT_COMMIT ?: 'Not available'}"""
            )
        }
    }
}
