# AWS Setup

## 1. Architecture

The application will run on AWS using the following services:

- **EC2:** Runs the frontend, Spring Boot backend, Prometheus, Grafana and Node Exporter in Docker containers.
- **RDS MySQL:** Stores application data in a managed database.
- **Amazon ECR:** Stores versioned backend and frontend Docker images.
- **IAM:** Provides permissions for EC2 and deployment operations.
- **Systems Manager (SSM):** Provides a secure way to manage the EC2 instance and run deployment commands.
- **CloudWatch:** Provides AWS instance and RDS monitoring.

## 2. Network Design

The deployment will use an AWS VPC with public and private subnets.

- EC2 will be placed in a public subnet for initial assessment access.
- RDS will be placed in private subnets and will not be publicly accessible.
- EC2 will connect to RDS over MySQL port 3306.
- The application will connect to RDS using its private endpoint.

## 3. Security Groups

### EC2 Security Group

Allow only the ports required for the deployment:

- HTTP port 80 for the frontend.
- SSH port 22 restricted to my own public IP, if SSH is enabled.
- Monitoring ports should not be exposed publicly unless required; access Grafana through a restricted method.

The backend port should not be opened to the internet if requests can be routed through the frontend or a reverse proxy.

### RDS Security Group

- Allow inbound MySQL traffic on port 3306 only from the EC2 security group.
- Do not allow public inbound access.
- Do not expose the database directly to the internet.

## 4. IAM

The EC2 instance will use an IAM instance role instead of storing AWS access keys on the server.

The role will grant only the permissions required by the deployment, such as pulling application images from ECR and accessing required SSM parameters.

Jenkins will use a separate restricted identity for publishing images and initiating deployments.

## 5. Secrets and Configuration

Database credentials and API credentials must not be committed to Git.

The deployment will use environment variables populated from AWS Systems Manager Parameter Store or AWS Secrets Manager. Sensitive values should be stored as secure parameters or secrets and accessed only by authorized identities.

## 6. Database

RDS will use MySQL, matching the application's database engine.

The setup should enable automated backups and use a suitable backup retention period. Multi-AZ can be considered if the availability requirement and budget justify the additional cost.

## 7. CI/CD Deployment Flow

1. Jenkins checks out the Git repository.
2. The pipeline runs tests and security scans.
3. Docker images are built and tagged with the Git commit.
4. Approved images are pushed to Amazon ECR.
5. Jenkins initiates deployment on EC2 using SSM.
6. EC2 pulls the new images and starts the containers.
7. Jenkins performs a health check.
8. Jenkins sends an email with the build result.

## 8. Monitoring

Prometheus collects application and host metrics. Grafana displays dashboards and alerts. CloudWatch provides AWS-level metrics for EC2 and RDS.

## 9. Cost and Cleanup

Use suitable small instance sizes for assessment testing. Review AWS pricing before creating resources.
