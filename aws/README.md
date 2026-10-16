# TodoSummaryAssistant — DevOps Assessment

## 1. Project Overview

TodoSummaryAssistant is a full-stack application with a Spring Boot backend, React frontend, and MySQL database.

This repository adds DevOps automation to containerize, test, deploy, and monitor the application.

The focus is repeatable deployment, security, observability, and operational recovery without changing application business logic unnecessarily.

## 2. Technology Stack

- **Backend:** Java 17, Spring Boot 3.4.5, Maven
- **Frontend:** React 19, Create React App
- **Database:** MySQL on AWS RDS for production
- **Containers:** Docker and Docker Compose
- **CI/CD:** Jenkins
- **Container registry:** Amazon ECR
- **Infrastructure:** Terraform, run locally
- **Deployment:** AWS Systems Manager
- **Monitoring:** Prometheus, Grafana, Node Exporter

## 3. Repository Structure

```text
TodoSummaryAssistant/
├── Backend/todo-summary-assistant/
│   ├── Dockerfile
│   └── .dockerignore
├── Frontend/todo/
│   ├── Dockerfile
│   └── .dockerignore
├── aws/
│   ├── architecture-diagram.png
│   ├── aws-setup.md
│   └── iac/
├── monitoring/
│   ├── prometheus.yml
│   ├── alert-rules.yml
│   └── grafana-dashboard.json
├── scripts/
├── Jenkinsfile
├── docker-compose.yml
├── .env.example
├── FAILURE_AND_ROLLBACK.md
└── MONITORING_AND_OPERATIONS.md
```

## 4. Prerequisites

Install the following tools for local development:

- Git
- Docker Desktop with Docker Compose
- Java 17, if running the backend outside Docker
- Node.js and npm, if running the frontend outside Docker
- AWS CLI and Terraform, for AWS infrastructure work

The Jenkins agent additionally needs Docker access, AWS CLI, Git, Java/Maven, Node.js/npm, and the security scanning tools configured by the pipeline.

## 5. Configuration and Secrets

Copy `.env.example` to `.env` for local development and provide appropriate local values.

Configuration includes:

- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`
- `COHERE_API_KEY`
- `SLACK_WEBHOOK_URL`
- `CORS_ALLOWED_ORIGINS`
- `GRAFANA_USER`
- `GRAFANA_PASSWORD`

Never commit `.env`, credentials, access keys, private keys, or real secrets.

For AWS deployment, keep database and integration credentials in AWS Secrets Manager and grant access through an IAM role. Do not put secret values in the Docker image or repository.

## 6. Local Development

From the repository root, build the containers:

```bash
docker compose build
```

Start the local stack:

```bash
docker compose up -d
```

Check service status and logs:

```bash
docker compose ps
docker compose logs -f backend
```

Stop the services:

```bash
docker compose down
```

The local Compose configuration requires the appropriate `.env` values and a reachable MySQL database. Verify the frontend's API URL and backend connectivity before considering the local deployment successful.

Default local endpoints, if the services are running and configured:

- Frontend: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001`
- Backend health: `http://localhost:8080/actuator/health`

The backend health endpoint requires Spring Boot Actuator to be installed and enabled. The metrics endpoint is `http://localhost:8080/actuator/prometheus` when Micrometer Prometheus support is configured.

## 7. Tests

Run backend tests from the backend directory:

```bash
./mvnw test
```

On Windows PowerShell:

```powershell
.\mvnw.cmd test
```

Run frontend tests:

```bash
npm ci
npm test -- --watchAll=false
```

Run the frontend production build:

```bash
npm run build
```

## 8. CI/CD Pipeline

The Jenkins pipeline is designed to perform these steps:

1. Check out the source code.
2. Verify the required tools and configuration.
3. Scan the repository for secrets.
4. Run backend and frontend tests.
5. Scan dependencies.
6. Build Docker images tagged with the Git commit.
7. Scan the built images.
8. Push the images to Amazon ECR.
9. Deploy the selected release to the application EC2 through AWS Systems Manager.
10. Check application health and fail the build if deployment fails.

Jenkins configuration and AWS IAM permissions must be completed before the pipeline can run. Configure a GitHub webhook or the equivalent Jenkins SCM trigger for automatic builds.

## 9. AWS Architecture

Terraform is run locally to provision and update AWS infrastructure.

- EC2 runs the containerized application.
- RDS MySQL stores application data and is not publicly accessible.
- The RDS security group permits database access only from the application EC2 security group.
- IAM roles provide AWS permissions without static AWS access keys.
- ECR stores application images.
- Systems Manager executes deployment commands.
- Prometheus and Grafana provide monitoring and dashboards.

See `aws/aws-setup.md` and `aws/architecture-diagram.png` for the architecture and security design.

## 10. Monitoring

Prometheus is configured to collect application metrics and host metrics.

Grafana presents operational metrics such as:

- Backend availability
- HTTP request rate
- HTTP error rate
- Request latency
- Host CPU usage
- Container restarts, when container metrics are configured

The alert rules include backend availability and high host CPU usage. Alert delivery requires a configured Alertmanager receiver.

## 11. Failure and Recovery

See `FAILURE_AND_ROLLBACK.md` for the recovery procedures covering failed deployments, application crashes, Jenkins outages, leaked secrets, EC2 failures, and RDS outages.

See `MONITORING_AND_OPERATIONS.md` for metrics, logs, alerting, and operational checks.

Container rollback does not automatically reverse database schema changes. Database migrations must be planned to remain compatible with the previous application version.

## 12. Security Considerations

- Run application containers as non-root users.
- Keep secrets out of Git and Docker images.
- Use least-privilege IAM roles.
- Keep RDS private.
- Restrict EC2 inbound ports to those required by the application.
- Avoid exposing Prometheus, Grafana, or internal metrics endpoints publicly.
- Use versioned container images and verify health after deployment.
- Review Terraform plans before applying infrastructure changes.

## 13. Implementation Status

The repository files and configuration must be tested in the target environment before this project is considered complete.

Before submission, verify:

- Both Docker images build and run.
- Backend and frontend tests pass.
- The Jenkins pipeline completes from source checkout through deployment.
- RDS is private and reachable from the application EC2.
- Prometheus collects real application and host metrics.
- Grafana dashboards display populated data.
- Alerts are evaluated and notification delivery is configured.
- Failed deployments are detected and rollback works.
- No real credentials or secrets are committed.
