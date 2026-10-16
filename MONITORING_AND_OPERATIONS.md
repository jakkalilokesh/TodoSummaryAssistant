# Monitoring and Operations

## 1. Monitoring Overview

The application will run on AWS EC2 using Docker containers, with MySQL hosted on AWS RDS. Prometheus will collect metrics, and Grafana will display dashboards and alerts.

## 2. Metrics to Monitor

| Metric | Purpose |
|---|---|
| Request rate | Understand application traffic |
| Error rate | Identify failed requests |
| Response latency | Detect slow API responses |
| CPU usage | Identify high processor usage on EC2 |
| Memory usage | Detect memory pressure |
| Disk usage | Prevent the server from running out of space |
| Container uptime | Check whether application containers are running |
| Database availability | Identify database connection problems |

Node Exporter will collect host metrics. Spring Boot Actuator and Micrometer will expose backend metrics to Prometheus. Container metrics can be added using cAdvisor.

## 3. Important Logs

- **Backend logs:** application errors, API failures and database connection errors.
- **Frontend and web server logs:** HTTP errors and requests that fail.
- **Docker logs:** container startup failures and restarts.
- **Jenkins logs:** failed builds, security scan results and deployment errors.
- **RDS logs:** database errors and connection issues.

Logs should be reviewed during incidents and retained according to the project's needs.

## 4. Alerts

The initial Prometheus alert rules cover:

- **BackendDown:** triggers when Prometheus cannot scrape the backend for one minute.
- **HighCPUUsage:** triggers when host CPU usage remains above 80% for five minutes.

Grafana alerting or an alert notification service must be configured to deliver notifications.

## 5. Detecting Problems Early

1. Review Grafana dashboards for traffic, errors and latency.
2. Investigate alerts when service availability or resource usage crosses a threshold.
3. Check backend, Docker and database logs to identify the cause.
4. Verify the application's health after each deployment.
5. Review Jenkins test and security scan results before allowing deployment.

## 6. Operational Practices

- Keep secrets in Jenkins credentials or AWS secret-management services.
- Restrict database access to the EC2 security group.
- Use versioned Docker images so a previous release can be redeployed.
- Keep RDS backups enabled and document recovery procedures.
- Remove unused AWS resources after assessment testing to avoid unnecessary charges.

## 7. Current Limitations

The Prometheus configuration depends on the backend exposing `/actuator/prometheus` and Node Exporter being deployed. These components must be configured and tested before the dashboards and alerts can provide reliable production monitoring.