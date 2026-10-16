# AWS Setup

## Architecture

- EC2 hosts the Dockerized backend and frontend.
- RDS MySQL stores application data and is not publicly accessible.
- ECR stores versioned Docker images.
- IAM instance roles provide AWS access without static AWS keys.
- AWS Systems Manager (SSM) executes remote deployment commands.
- Prometheus and Grafana provide metrics and dashboards.

## Networking and security

- Place RDS in private subnets.
- Configure the RDS security group to allow MySQL traffic only from the application EC2 security group.
- Do not assign RDS a public endpoint.
- Allow only the application ports required by the deployment.
- Restrict administrative access and do not expose monitoring ports publicly.
- Keep database credentials and integration secrets in AWS Secrets Manager.

## IAM

The Jenkins role should have only the permissions needed to:
- Push images to the designated ECR repositories.
- Upload deployment artifacts to the designated S3 bucket.
- Discover the intended application EC2 instance.
- Send and inspect SSM deployment commands.

The application EC2 role should have only the permissions needed to:
- Register with and communicate through SSM.
- Pull images from the designated ECR repositories.
- Read deployment artifacts from the designated S3 prefix.
- Retrieve the specific application secret from Secrets Manager.

## Terraform

Terraform is run locally to provision and update infrastructure.
Review the plan before applying changes. Protect Terraform state because it may contain sensitive values.

## Operational notes

- Use immutable release identifiers based on Git commits.
- Verify application health after each deployment.
- Keep a previous known-good image reference for rollback.
- Configure RDS backups and review retention settings.
- Monitor AWS costs and remove assessment resources when no longer needed.
