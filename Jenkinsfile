
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        AWS_REGION      = "${env.AWS_REGION}"
        ARTIFACT_BUCKET = "${env.ARTIFACT_BUCKET}"
        BACKEND_REPO    = "${env.BACKEND_REPO}"
        FRONTEND_REPO   = "${env.FRONTEND_REPO}"
        APP_INSTANCE_ID = 'i-0979ce44516967c47'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm

                script {
                    def commit = sh(
                        script: 'git rev-parse --short=12 HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "${commit}-${env.BUILD_NUMBER}"
                    echo "Using unique immutable ECR image tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Validate Configuration') {
            steps {
                sh '''
                    set -eu

                    : "${AWS_REGION:?Configure AWS_REGION in Jenkins}"
                    : "${ARTIFACT_BUCKET:?Configure ARTIFACT_BUCKET in Jenkins}"
                    : "${BACKEND_REPO:?Configure BACKEND_REPO in Jenkins}"
                    : "${FRONTEND_REPO:?Configure FRONTEND_REPO in Jenkins}"
                    : "${APP_INSTANCE_ID:?Application instance ID is required}"

                    for tool in docker aws jq gitleaks trivy npm; do
                        if ! command -v "$tool" >/dev/null 2>&1; then
                            echo "ERROR: Required tool not found: $tool" >&2
                            exit 1
                        fi
                    done

                    docker --version
                    aws --version
                    npm --version
                    trivy --version
                '''
            }
        }

        stage('Secret Scan') {
            steps {
                sh '''
                    set -eu
                    gitleaks detect --source . --redact --exit-code 1
                '''
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
                    junit(
                        allowEmptyResults: true,
                        testResults: 'Backend/todo-summary-assistant/target/surefire-reports/*.xml'
                    )
                }
            }
        }

        stage('Frontend Tests and Build') {
            steps {
                dir('Frontend/todo') {
                    sh '''
                        set -eu
                        npm ci
                        CI=true npm test -- --watchAll=false --passWithNoTests
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
                        --exit-code 0 \
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

                    docker build --pull \
                        -t "$BACKEND_IMAGE" \
                        Backend/todo-summary-assistant

                    docker build --pull \
                        -t "$FRONTEND_IMAGE" \
                        Frontend/todo
                '''
            }
        }

        stage('Image Scan') {
            steps {
                sh '''
                    set -eu

                    trivy image \
                        --scanners vuln \
                        --severity HIGH,CRITICAL \
                        --exit-code 0 \
                        "$BACKEND_IMAGE"

                    trivy image \
                        --scanners vuln \
                        --severity HIGH,CRITICAL \
                        --exit-code 0 \
                        "$FRONTEND_IMAGE"
                '''
            }
        }

        stage('Push Images to ECR') {
            steps {
                sh '''
                    set -eu

                    aws ecr get-login-password --region "$AWS_REGION" |
                        docker login \
                            --username AWS \
                            --password-stdin "$ECR_REGISTRY"

                    docker push "$BACKEND_IMAGE"
                    docker push "$FRONTEND_IMAGE"
                '''
            }
        }

        stage('Upload Deployment Files') {
            steps {
                sh '''
                    set -eu

                    COMPOSE_FILE="aws/docker-compose.prod.yml"

                    test -f "$COMPOSE_FILE" || {
                        echo "ERROR: $COMPOSE_FILE not found."
                        exit 1
                    }

                    for file in deploy-app.sh health-check.sh rollback.sh; do
                        test -f "scripts/$file" || {
                            echo "ERROR: scripts/$file not found."
                            exit 1
                        }
                    done

                    test -f "scripts/trigger-deploy.sh" || {
                        echo "ERROR: scripts/trigger-deploy.sh not found."
                        exit 1
                    }

                    DESTINATION="s3://${ARTIFACT_BUCKET}/releases/${IMAGE_TAG}"

                    aws s3 cp "$COMPOSE_FILE" \
                        "${DESTINATION}/docker-compose.prod.yml"

                    for file in deploy-app.sh health-check.sh rollback.sh; do
                        aws s3 cp "scripts/$file" "${DESTINATION}/$file"
                    done

                    echo "Deployment files uploaded successfully."
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
            script {
                def appIp = sh(
                    script: '''
                        aws ec2 describe-instances \
                            --region "$AWS_REGION" \
                            --instance-ids "$APP_INSTANCE_ID" \
                            --query 'Reservations[0].Instances[0].PublicIpAddress' \
                            --output text
                    ''',
                    returnStdout: true
                ).trim()

                if (!appIp || appIp == 'None') {
                    error('Deployment finished, but AWS did not return a public IP for the application instance.')
                }

                echo """
========================================================
          TODO SUMMARY ASSISTANT - DEPLOYED
========================================================

Application:
http://${appIp}/

Grafana:
http://${appIp}:3000/

Prometheus:
http://${appIp}:9090/

Commit / Image tag:
${env.IMAGE_TAG}

========================================================
Monitoring URLs assume Grafana and Prometheus are running
on this EC2 instance and their ports are reachable.
========================================================
"""
            }
        }

        failure {
            echo 'Pipeline failed. Check the first failed stage in Console Output.'
        }
    }
}
