# Failure Handling and Rollback

## Overview

Deployments can fail because of application bugs, infrastructure problems, configuration mistakes, or unavailable services. The goal is to identify the problem quickly, avoid exposing secrets, and restore the last working release where possible.

## 1. A Faulty Version Is Deployed. How Do You Roll Back?

If a new release causes errors, check the Jenkins console output and application logs to identify the problem.

The deployment should keep track of the last known-good image and configuration. If rollback is needed, restore that version and restart the application containers. Then check the application again.

The rollback script is part of the project, but its behavior should be tested before relying on it for production recovery.

## 2. The Application Crashes After Deployment. What Happens?

The Docker Compose configuration uses a restart policy to restart containers after certain failures.

If the application still does not work, inspect the container status and logs:

```bash
docker ps -a
docker logs --tail 100 todo-backend
docker logs --tail 100 todo-frontend
```

The health-check script reports container status and prints recent logs when the check fails. A running container does not always mean the application is functioning correctly.

## 3. The CI/CD Tool Becomes Unavailable. Can You Still Deploy?

A deployment cannot be triggered through Jenkins while Jenkins is unavailable.

An authorized operator can use AWS Systems Manager to run the existing deployment process manually, provided the necessary images and deployment artifacts already exist and the operator has the required permissions.

Once Jenkins is restored, the pipeline can be used again for normal automated deployments.

## 4. Secrets Are Leaked. What Steps Do You Take?

If a password, API key, or webhook URL is exposed:

1. Revoke or rotate the affected credential immediately.
2. Update the secret store with the replacement value.
3. Check logs and repository history for further exposure.
4. Remove the secret from the repository where appropriate.
5. Review access logs and IAM permissions.
6. Confirm the application works with the replacement credential.

Removing a secret from the latest commit is not enough if it remains in Git history. Never publish real credentials in an issue, screenshot, or log.

## 5. The EC2 Instance Fails. How Do You Recover?

First, check the instance state and AWS Systems Manager connectivity.

If the instance can be recovered, restore its service and verify Docker and the application containers. If it cannot be recovered, create or restore an application instance, configure its IAM role and security groups, and redeploy the known-good images and configuration.

The application should remain connected to the managed RDS database, provided the database itself is healthy and network access is configured correctly.

## 6. The RDS Database Becomes Unavailable. What Is the Impact and Recovery Plan?

The backend may be unable to read or save todo data while the database is unavailable. Database-dependent operations may fail until connectivity is restored.

The recovery process is to check RDS status, database connectivity, credentials, and security-group rules. If recovery from the underlying issue is not possible, restore the database using an appropriate backup or snapshot.

Automated backups, retention settings, and Multi-AZ deployment should be configured according to recovery requirements and budget. They should not be assumed to be enabled without checking the actual RDS configuration.

## Conclusion

The project includes deployment and rollback scripts to support recovery. These procedures should be tested in a safe environment so that a failed release or infrastructure incident can be handled consistently.
