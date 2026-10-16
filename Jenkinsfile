pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        AWS_REGION = "${env.AWS_REGION}"
        ARTIFACT_BUCKET = "${env.ARTIFACT_BUCKET}"
        BACKEND_REPO = "${env.BACKEND_REPO}"
        FRONTEND_REPO = "${env.FRONTEND_REPO}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse --short=12 HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Validate Configuration') {
            steps {
                sh '''
                    set -eu

                    for name in AWS_REGION ARTIFACT_BUCKET BACKEND_REPO FRONTEND_REPO
                    do
                      eval 'value=${'${name}':-}'
                      if [ -z "$value" ] || [ "$value" = "null" ]; then
                        echo "ERROR: Jenkins variable $name is not configured." >&2
                        exit 1
                      fi
                    done

                    command -v docker
                    command -v aws
                    command -v jq
                    command -v gitleaks
                    command -v trivy
                '''
            }
        }

        stage('Secret Scan') {
            steps {
                sh 'gitleaks detect --source . --redact --exit-code 1'
            }
        }

        stage('Backend Tests') {
            steps {
                dir('Backend/todo-summary-assistant') {
                    withEnv([
                        'JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64',
                        'PATH+JAVA17=/usr/lib/jvm/java-17-openjdk-amd64/bin'
                    ]) {
                        sh '''
                            set -eu
                            java -version
                            javac -version
                            chmod +x mvnw
                            ./mvnw --batch-mode test
                        '''
                    }
                }
            }
            post {
                always {
                    junit allowEmptyResults: true,
                        testResults: 'Backend/todo-summary-assistant/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Frontend Tests and Build') {
            steps {
                dir('Frontend/todo') {
                    sh '''
                        set -eu
                        npm ci
                        CI=true npm test -- --watchAll=false
                        npm run build
                    '''
                }
            }
        }

        stage('Dependency Scan') {
            steps {
                sh '''
                    set -eu
                    trivy fs \
                      --scanners vuln \
                      --severity HIGH,CRITICAL \
                      --exit-code 1 \
                      .
                '''
            }
        }

        stage('Build Images') {
            steps {
                script {
                    env.AWS_ACCOUNT_ID = sh(
                        script: 'aws sts get-caller-identity --query Account --output text',
                        returnStdout: true
                    ).trim()

                    env.ECR_REGISTRY =
                        "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"

                    env.BACKEND_IMAGE =
                        "${env.ECR_REGISTRY}/${env.BACKEND_REPO}:${env.IMAGE_TAG}"

                    env.FRONTEND_IMAGE =
                        "${env.ECR_REGISTRY}/${env.FRONTEND_REPO}:${env.IMAGE_TAG}"
                }

                sh '''
                    set -eu
                    docker build --pull -t "$BACKEND_IMAGE" Backend/todo-summary-assistant
                    docker build --pull -t "$FRONTEND_IMAGE" Frontend/todo
                '''
            }
        }

        stage('Image Scan') {
            steps {
                sh '''
                    set -eu
                    trivy image --severity HIGH,CRITICAL --exit-code 1 "$BACKEND_IMAGE"
                    trivy image --severity HIGH,CRITICAL --exit-code 1 "$FRONTEND_IMAGE"
                '''
            }
        }

        stage('Push Images to ECR') {
            steps {
                sh '''
                    set -eu
                    aws ecr get-login-password --region "$AWS_REGION" |
                      docker login --username AWS --password-stdin "$ECR_REGISTRY"

                    docker push "$BACKEND_IMAGE"
                    docker push "$FRONTEND_IMAGE"
                '''
            }
        }

        stage('Upload Deployment Files') {
            steps {
                sh '''
                    set -eu
                    RELEASE_PREFIX="releases/${IMAGE_TAG}"
                    DESTINATION="s3://${ARTIFACT_BUCKET}/${RELEASE_PREFIX}"

                    aws s3 cp docker-compose.prod.yml "${DESTINATION}/docker-compose.prod.yml"

                    for file in deploy-app.sh health-check.sh rollback.sh
                    do
                      aws s3 cp "scripts/${file}" "${DESTINATION}/${file}"
                    done
                '''
            }
        }

        stage('Deploy through SSM') {
            steps {
                sh '''
                    set -eu
                    bash scripts/trigger-deploy.sh
                '''
            }
        }
    }

    post {
        always {
            sh '''
                docker logout "${ECR_REGISTRY:-invalid}" >/dev/null 2>&1 || true
                docker image prune -f || true
            '''
        }

        success {
            echo "Deployment succeeded for commit ${env.IMAGE_TAG}."
        }

        failure {
            echo 'Pipeline failed. Review the failed stage and console output.'
        }
    }
}
