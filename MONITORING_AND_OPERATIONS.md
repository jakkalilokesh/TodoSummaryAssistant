# Monitoring and Operations

## Overview

Monitoring helps identify problems before they cause a major interruption. For TodoSummaryAssistant, the important areas are application availability, container health, server resources, and database connectivity.

The project is intended to use Prometheus for collecting metrics and Grafana for displaying dashboards and alerts.

## 1. What Metrics Should Be Monitored?

### Application Metrics

Application metrics help show whether the service is responding normally.

Useful measurements include:

- Request rate.
- HTTP error rate.
- Response latency.
- Application availability.
- Database connection failures.

These metrics require suitable application instrumentation and a configured metrics endpoint.

### Server Metrics

Server metrics help identify whether the EC2 instance is running out of resources.

Monitor:

- CPU utilization.
- Memory usage.
- Disk usage.
- Network activity.

Node Exporter can provide host-level metrics when it is installed and configured.

### Container Metrics

Container monitoring helps identify repeated restarts and resource problems.

Useful measurements include:

- Container uptime.
- Container restarts.
- CPU and memory usage.
- Container availability.

cAdvisor can be used to collect container resource metrics if it is deployed.

### Database Metrics

RDS monitoring should cover database availability, CPU utilization, storage capacity, and database connections. Database logs and connection errors are also useful when investigating application failures.

## 2. Logs That Matter

The following logs are useful during troubleshooting:

- Jenkins console output for pipeline failures.
- AWS Systems Manager command output for remote deployment failures.
- Backend container logs for application and database errors.
- Frontend container logs for startup and serving errors.
- RDS logs and events for database problems.
- Prometheus and Grafana logs when monitoring is unavailable.

Logs should not contain database passwords, API keys, or other sensitive values.

## 3. Important Alerts

The monitoring setup should include meaningful alerts, such as:

- **Service unavailable:** The application or an expected metrics target is down.
- **High CPU utilization:** The host remains under heavy load for a sustained period.
- **High error rate:** Application failures rise above an agreed threshold.
- **Low disk space:** The server is running out of available storage.
- **Repeated container restarts:** A service repeatedly fails to stay running.

Alert thresholds should reflect normal application behavior. Short-lived spikes should not generate unnecessary notifications.

## 4. Prometheus and Grafana

Prometheus collects metrics from configured targets. Grafana uses those metrics to display dashboards and evaluate configured alerts.

The project monitoring directory is intended to contain:

```text
monitoring/
├── prometheus.yml
├── alert-rules.yml
└── grafana-dashboard.json
```

The Prometheus configuration should identify the application metrics endpoint and any deployed exporters. The Grafana dashboard should display application performance and infrastructure health.

These files must match the services actually deployed. Adding configuration files alone does not prove that metrics are being collected or alerts are firing.

## 5. Basic Operational Checks

Check whether the application containers are running:

```bash
docker ps
```

Inspect their recent logs:

```bash
docker logs --tail 100 todo-backend
docker logs --tail 100 todo-frontend
```

Check the production Compose services:

```bash
docker compose \
  -f /opt/todo-assistant/docker-compose.prod.yml \
  ps
```

If a deployment fails, review the Jenkins console and the associated Systems Manager command output before changing the application configuration.

## 6. How Problems Are Detected Early

Automated tests help catch application issues before images are published. Security scans help identify potential risks in source files and container images. Deployment health checks can detect containers that fail to start or reach their expected status.

Prometheus and Grafana can provide additional visibility into application and infrastructure behavior once their targets, dashboards, and alerts are configured.

## Conclusion

A useful monitoring setup focuses on service availability, errors, latency, infrastructure capacity, and database health. Keeping alerts focused and reviewing logs during failures helps reduce troubleshooting time and avoid unnecessary notifications.
