# Failure and Rollback

## 1. Faulty Version Is Deployed

If a new application version fails after deployment, I will check the Jenkins logs, application logs and health-check results. I will redeploy the previous working Docker image using its version tag. After rollback, I will verify the application health and database connectivity.

## 2. Application Crashes After Deployment

Docker logs and container status will help identify the cause. I will check the health endpoint, environment variables, database connectivity and resource usage. If the issue cannot be fixed quickly, I will roll back to the previous working image.

## 3. Jenkins Is Unavailable

The application already running on EC2 will continue running independently of Jenkins. For an urgent recovery, I can manually deploy a previously tested image from the container registry using an authorized access method. Automated deployment resumes when Jenkins is restored.

## 4. Secrets Are Leaked

I will revoke or rotate the exposed credentials immediately, remove the secret from the source where possible, and review Git history and relevant logs. I will check for unauthorized access and move credentials into Jenkins Credentials or AWS Secrets Manager/SSM Parameter Store. Removing a secret from the latest commit alone does not invalidate it.

## 5. EC2 Instance Fails

I will check the instance status and AWS monitoring information. If recovery is not possible, I will provision a replacement instance, install or configure Docker, restore the required configuration, and deploy the last known-good image. I will verify connectivity to RDS and application health.

Terraform can help recreate the infrastructure consistently. Deployment configuration and secrets must be stored separately from the failed instance.

## 6. RDS Database Becomes Unavailable

The application may fail to read or write todo data while RDS is unavailable. I will check RDS status, connectivity, security groups and database logs. I will restore service by resolving the connection or database issue, or recover from an appropriate RDS backup or snapshot if necessary.

Automated backups should be enabled. Multi-AZ deployment can improve database availability, but its cost and configuration must be considered for this assessment. I will verify database recovery and application functionality before declaring the incident resolved.

## Recovery Verification

After any recovery or rollback, I will:

1. Check that the backend and frontend are reachable.
2. Verify backend connectivity to RDS.
3. Test key todo operations.
4. Check Prometheus and Grafana for service health and errors.
5. Record the cause, recovery action and any follow-up improvements.