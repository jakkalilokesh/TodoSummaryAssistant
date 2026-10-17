# TodoSummaryAssistant — DevOps Project

An AWS-based DevOps implementation for TodoSummaryAssistant using Docker, Jenkins CI/CD, Amazon EC2, Amazon RDS, Amazon ECR, Amazon S3, AWS Systems Manager, and AWS Secrets Manager.

**Repository:** https://github.com/jakkalilokesh/TodoSummaryAssistant

**CI/CD:** Jenkins

**Deployment status:** Jenkins build #27 completed successfully, and the application interface was observed loading in a browser. Full production functionality and monitoring are not claimed as independently verified.

---

## 1. Project Objectives

- Containerize the React frontend and Spring Boot backend.
- Automate builds and tests through Jenkins.
- Scan source files and Docker images for security issues.
- Publish images to Amazon ECR.
- Store deployment artifacts in Amazon S3.
- Deploy to Amazon EC2 through AWS Systems Manager.
- Connect the backend to MySQL on Amazon RDS.
- Store database credentials in AWS Secrets Manager.
- Support application health checks and rollback.
- Configure Prometheus and Grafana for monitoring.

## 2. Technology Stack

| Component | Technology |
|---|---|
| Frontend | React |
| Backend | Spring Boot, Maven |
| Database | MySQL, Amazon RDS |
| Containers | Docker, Docker Compose |
| CI/CD | Jenkins |
| Registry | Amazon ECR |
| Artifact storage | Amazon S3 |
| Remote deployment | AWS Systems Manager |
| Secrets | AWS Secrets Manager |
| Infrastructure | Amazon EC2 |
| Security scanning | Gitleaks, Trivy |
| Monitoring | Prometheus, Grafana |

## 3. Architecture

```text
Developer
   |
   v
GitHub
   |
   v
Jenkins Pipeline
   |
   +--> Validate configuration
   +--> Scan secrets
   +--> Run backend tests
   +--> Test/build frontend
   +--> Scan files and images
   +--> Build Docker images
   |
   v
Amazon ECR
   |
   v
Amazon S3 deployment artifacts
   |
   v
AWS Systems Manager
   |
   v
Application EC2
   |
   +--> React frontend container
   +--> Spring Boot backend container
   |
   v
Amazon RDS for MySQL

Prometheus --> Metrics
Grafana --> Dashboards and alerts
```

This represents the intended deployment architecture. Monitoring configuration and production behavior depend on the actual deployed services.

## Architecture Diagram

![TodoSummaryAssistant DevOps Architecture](aws/architecture-diagram.png)

## 4. Repository Structure

```text
TodoSummaryAssistant/
├── Backend/
│   └── todo-summary-assistant/
│       ├── Dockerfile
│       └── .dockerignore
├── Frontend/
│   └── todo/
│       ├── Dockerfile
│       └── .dockerignore
├── aws/
│   ├── docker-compose.prod.yml
│   ├── aws-setup.md
│   └── iac/
├── monitoring/
│   ├── prometheus.yml
│   ├── alert-rules.yml
│   └── grafana-dashboard.json
├── scripts/
│   ├── deploy-app.sh
│   ├── health-check.sh
│   ├── rollback.sh
│   ├── setup-app-server.sh
│   └── trigger-deploy.sh
├── Jenkinsfile
├── .env.example
├── README.md
├── FAILURE_AND_ROLLBACK.md
└── MONITORING_AND_OPERATIONS.md
```

The tree shows the intended submission layout. Keep the existing application paths and include optional files only if they exist in the repository.

## 5. Prerequisites

Install the following tools on your development machine:

- Git
- Java and Maven compatible with the backend
- Node.js and npm compatible with the frontend
- Docker and Docker Compose
- AWS CLI, if you will manage AWS resources from your machine

For deployment, the AWS environment also requires:

- Jenkins with access to the source repository.
- An application EC2 instance registered with Systems Manager.
- An Amazon ECR repository for each application image.
- An S3 bucket for deployment artifacts.
- An Amazon RDS MySQL instance.
- A Secrets Manager secret containing database configuration.
- IAM permissions for the Jenkins and application instance roles.

## 6. Clone the Repository

Open a terminal and run:

```bash
git clone https://github.com/jakkalilokesh/TodoSummaryAssistant.git
cd TodoSummaryAssistant
```

Check the current branch and repository status:

```bash
git branch --show-current
git status
```

Use the branch configured for your Jenkins pipeline.

## 7. Configure Environment Variables

Create a local environment file from the example:

**Linux/macOS:**

```bash
cp .env.example .env
```

**Windows PowerShell:**

```powershell
Copy-Item .env.example .env
```

Populate the file with valid local development settings. Never commit the populated `.env` file.

The deployment uses the following configuration keys where applicable:

| Variable | Description |
|---|---|
| `DB_URL` | JDBC URL for MySQL |
| `DB_USERNAME` | MySQL username |
| `DB_PASSWORD` | MySQL password |
| `COHERE_API_KEY` | AI service key |
| `SLACK_WEBHOOK_URL` | Slack notification webhook |

For production, configure sensitive values through AWS Secrets Manager or the approved secret store rather than committing them to Git.

The production deployment expects the database secret to contain `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`.

## 8. Run the Application Locally

### Option A: Run with Docker Compose

If the repository contains a local `docker-compose.yml`, configure its required environment variables and run:

```bash
docker compose up --build -d
docker compose ps
docker compose logs --tail=100
```

Stop the services with:

```bash
docker compose down
```

These commands assume the local Compose file defines the application services. The production Compose file is `aws/docker-compose.prod.yml`.

### Option B: Run the backend

Navigate to the Spring Boot project directory, using the actual path in your checkout:

```bash
cd Backend/todo-summary-assistant
./mvnw test
./mvnw spring-boot:run
```

On Windows PowerShell:

```powershell
.\mvnw.cmd test
.\mvnw.cmd spring-boot:run
```

If the project does not include the Maven wrapper, use an installed Maven executable:

```bash
mvn test
mvn spring-boot:run
```

Set the required database and service configuration before starting the backend.

### Run the frontend

Open a second terminal and navigate to the React project directory:

```bash
cd Frontend/todo
npm ci
npm test -- --watchAll=false --passWithNoTests
npm run build
npm start
```

The development server's address and port depend on the frontend configuration.

If your repository uses different directory names, use the existing paths instead of renaming the application folders.

## 9. Build Docker Images

Build the backend image from its Dockerfile:

```bash
docker build \
  -t todo-assistant-backend:local \
  -f Backend/todo-summary-assistant/Dockerfile \
  Backend/todo-summary-assistant
```

Build the frontend image:

```bash
docker build \
  -t todo-assistant-frontend:local \
  -f Frontend/todo/Dockerfile \
  Frontend/todo
```

List the built images:

```bash
docker images
```

The Dockerfiles should use multi-stage builds where appropriate, avoid running the application as root, and exclude unnecessary files through `.dockerignore`.

## 10. AWS Infrastructure Setup

### 10.1 Configure AWS CLI

If you have an authorized AWS profile configured:

```bash
aws sts get-caller-identity
aws configure list
```

Use IAM roles for EC2 workloads. Do not place AWS access keys in application files or commit them to Git.

### 10.2 Amazon ECR

The Jenkins pipeline uses separate ECR repositories for the backend and frontend.

List the repositories:

```bash
aws ecr describe-repositories \
  --region ap-south-1
```

Authenticate Docker to ECR when performing an authorized manual push:

```bash
aws ecr get-login-password --region ap-south-1 |
  docker login \
    --username AWS \
    --password-stdin \
    323708468684.dkr.ecr.ap-south-1.amazonaws.com
```

The registry address above is the project environment's configured registry. Replace it if deploying into another AWS account or region.

Jenkins should build, tag, scan, and publish release images automatically.

### 10.3 Amazon S3

List the available buckets:

```bash
aws s3 ls
```

The pipeline uploads deployment artifacts under a versioned release prefix. Verify the configured bucket and release path in Jenkins rather than assuming a particular tag.

### 10.4 Amazon EC2 and Systems Manager

Check the application instance state:

```bash
aws ec2 describe-instances \
  --instance-ids i-0979ce44516967c47 \
  --region ap-south-1 \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text
```

The instance must be running, registered with Systems Manager, and have appropriate permissions and network connectivity.

### 10.5 Amazon RDS and Secrets Manager

Check RDS instance status:

```bash
aws rds describe-db-instances \
  --region ap-south-1 \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine]' \
  --output table
```

List secret metadata without printing secret values:

```bash
aws secretsmanager list-secrets \
  --region ap-south-1 \
  --query 'SecretList[*].[Name,ARN]' \
  --output table
```

Keep the RDS database private and restrict inbound database access to the application instance's security group. Store database credentials in Secrets Manager.

See `aws/aws-setup.md` for the project's infrastructure details.

## 11. Jenkins CI/CD Pipeline

The pipeline automates the release workflow.

| Stage | Purpose |
|---|---|
| Checkout | Retrieves the source revision |
| Validation | Checks required configuration |
| Gitleaks | Detects potential exposed secrets |
| Backend tests | Executes backend tests |
| Frontend tests/build | Tests and builds the frontend |
| Trivy filesystem scan | Scans project files and dependencies |
| Docker build | Builds application images |
| Trivy image scan | Scans built container images |
| ECR push | Publishes versioned images |
| S3 upload | Publishes deployment scripts and Compose configuration |
| SSM deployment | Runs the remote deployment script |
| Health check | Checks application container status |

### Trigger a deployment

1. Commit and push the intended changes to the configured Git branch.
2. Open the Jenkins dashboard.
3. Select the TodoSummaryAssistant pipeline.
4. Click **Build Now**, or use the configured Git webhook.
5. Open the new build's Console Output.
6. Confirm the result and inspect the deployment stage.

For a Git push from your local checkout:

```bash
git add .
git commit -m "Describe the change"
git push origin fresh-main
```

Review `git status` before using `git add .` to ensure you do not stage secrets, generated artifacts, or local configuration.

The pipeline uses versioned image tags to identify releases. Review Trivy findings before treating a release as production-approved; non-blocking scan behavior does not guarantee that vulnerabilities are absent.

## 12. Deployment Scripts

The repository's scripts have the following responsibilities:

| Script | Purpose |
|---|---|
| `scripts/setup-app-server.sh` | Installs required application-server dependencies on supported Ubuntu/Debian systems |
| `scripts/trigger-deploy.sh` | Submits and monitors the remote deployment through SSM |
| `scripts/deploy-app.sh` | Retrieves configuration, pulls images, and starts the application |
| `scripts/health-check.sh` | Checks deployed container status |
| `scripts/rollback.sh` | Implements the configured rollback procedure |

The trigger script has also been updated to attempt OS-aware dependency installation. Confirm the latest committed version before relying on that behavior.

### Check deployment containers

On the application EC2 instance, after connecting through an authorized session:

```bash
docker ps
docker compose -f /opt/todo-assistant/docker-compose.prod.yml ps
```

Inspect logs when needed:

```bash
docker logs --tail 100 todo-backend
docker logs --tail 100 todo-frontend
```

The exact container names must match the production Compose configuration.

## 13. Monitoring with Prometheus and Grafana

The intended monitoring stack includes Prometheus for metrics collection and Grafana for dashboards and alerts.

The `monitoring/` directory should contain:

- `prometheus.yml` — scrape targets and collection settings.
- `alert-rules.yml` — alert rules.
- `grafana-dashboard.json` — dashboard definition.

Recommended metrics include application availability, request rate, error rate, latency, host CPU/memory/disk usage, container restarts, and database availability.

Monitoring is operational only when the services, scrape targets, dashboards, and alert rules are configured and working. A pipeline message that prints monitoring URLs is not sufficient proof.

Refer to `MONITORING_AND_OPERATIONS.md` for operational guidance.

## 14. Health Checks and Rollback

After deployment, the health-check script checks the state of the backend and frontend containers. Container status alone does not guarantee that the application or its database integration is functioning correctly.

For failures, inspect the Jenkins console, SSM invocation output, Docker Compose status, and application logs.

Refer to `FAILURE_AND_ROLLBACK.md` for the recovery approach covering:

1. Faulty application releases.
2. Application crashes.
3. CI/CD service unavailability.
4. Leaked secrets.
5. EC2 instance failures.
6. RDS database outages.

## 15. Security Practices

- Do not commit secrets or populated environment files.
- Use IAM roles and least-privilege permissions.
- Store database credentials in Secrets Manager.
- Keep RDS private.
- Restrict security-group rules to required traffic.
- Use non-root containers.
- Review Gitleaks and Trivy results.
- Maintain identifiable image tags and rollback information.
- Use HTTPS before exposing the application as a production service.

## 16. Deployment Status

Jenkins build #27 completed with `SUCCESS`, and the TodoSummaryAssistant interface was observed loading in the browser.

This confirms the reported pipeline result and interface availability at the time of observation. It does not, by itself, verify every application integration, monitoring dashboard, alert, or recovery scenario.

The browser session used HTTP, so HTTPS should be configured before production handover.

## 17. Conclusion

This project demonstrates DevOps automation for a full-stack application using Docker, Jenkins, and AWS services. It includes a pipeline for testing, image publishing, artifact delivery, and remote deployment, together with scripts and documentation for operational support.

The repository is intended to provide reproducible setup and deployment instructions without exposing production secrets.

---

**Project:** TodoSummaryAssistant — DevOps Assessment

**Source repository:** https://github.com/jakkalilokesh/TodoSummaryAssistant
