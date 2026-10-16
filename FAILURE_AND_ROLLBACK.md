# Failure and Rollback

## 1. A faulty version is deployed

The deployment uses a commit-specific image tag. If health checks fail, the deployment script attempts to restore the previous known-good image versions. Investigate logs and tests before redeploying.

## 2. The application crashes after deployment

Docker restart policies attempt to restart crashed containers. Prometheus should alert when the backend target is unavailable. Review container logs, health status, configuration, database connectivity, and resource usage.

## 3. Jenkins becomes unavailable

The application continues running independently of Jenkins. A release can be performed through an approved, documented operational procedure using a known image tag and the same deployment mechanism, provided the necessary AWS access and artifacts remain available. Record the manual release and reconcile it with Jenkins afterward.

## 4. Secrets are leaked

Revoke or rotate the affected secret immediately. Remove the secret from active configuration, inspect logs and repository history, review access logs, and redeploy using the rotated value. Removing a secret from the latest commit alone is insufficient if it exists in Git history.

## 5. The EC2 instance fails

Recover or replace the instance using the documented infrastructure configuration. Attach the correct instance role, verify SSM registration, networking, and security groups, then deploy the last known-good image versions. Confirm RDS connectivity and application health.

## 6. RDS becomes unavailable

The application may fail requests that depend on the database. Check RDS events, connectivity, security groups, and database health. Restore from a suitable backup or snapshot if necessary. Multi-AZ can improve availability but must be configured and may incur additional cost. Validate data recovery and application connectivity before reopening traffic.

## Limitations

Container rollback does not automatically reverse database schema changes. Database changes should be backward-compatible, and backup restoration procedures should be tested separately.
