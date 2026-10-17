# AWS Setup and Deployment

## Overview

TodoSummaryAssistant runs on AWS using EC2 for the application, RDS for the MySQL database, and other AWS services to support deployment.

The aim is to make deployment easier to manage without manually copying application files or storing database passwords in the source code.

## AWS Services Used

- **EC2:** Runs the frontend and backend Docker containers.
- **RDS:** Stores application data in a managed MySQL database.
- **ECR:** Stores the backend and frontend Docker images.
- **S3:** Stores deployment files used by the Jenkins pipeline.
- **Systems Manager (SSM):** Allows Jenkins to run deployment commands on the EC2 instance.
- **Secrets Manager:** Stores database credentials securely.
- **IAM:** Controls which AWS resources Jenkins and the application server can access.

## How Deployment Works

1. A developer pushes code to GitHub.
2. Jenkins checks out the code, runs tests, scans for security issues, and builds the Docker images.
3. The images are pushed to Amazon ECR.
4. Deployment scripts and configuration files are uploaded to Amazon S3.
5. Jenkins uses AWS Systems Manager to trigger deployment on the application EC2 instance.
6. The deployment script installs required dependencies when needed, retrieves database credentials, pulls the images, and starts the containers.
7. A health-check script checks the application containers and reports a failure if they do not meet the expected status.

## Database Configuration

The application uses MySQL hosted on Amazon RDS. Database credentials are stored in AWS Secrets Manager rather than committed to GitHub.

The deployment expects these configuration values:

- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`

The RDS database should not be publicly accessible. Its security group should allow MySQL traffic only from the application EC2 security group.

## IAM and Network Security

The EC2 instance uses an IAM role to access the AWS services required for deployment. AWS access keys should not be hardcoded in scripts or application configuration.

Security groups should allow only the ports needed by the application and administration. Database access should be restricted to the application server, and administrative access should be limited to authorized users.

## Deployment Requirements

Before deployment, make sure:

- The application EC2 instance is running and connected to Systems Manager.
- Jenkins has the required permissions to publish images and start SSM commands.
- The application instance can access ECR, S3, Secrets Manager, and required package repositories.
- The ECR images and S3 deployment files exist for the release.
- The database secret contains valid connection details.
- Docker and Docker Compose can run on the application instance.

## Current Status

The Jenkins pipeline has completed successfully in a recorded build, and the application interface has been observed in a browser. The architecture and configuration described here document the intended setup; individual AWS security settings and all application integrations should not be considered verified solely from that result.
