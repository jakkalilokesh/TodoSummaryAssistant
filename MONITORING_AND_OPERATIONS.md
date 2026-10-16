# Monitoring and Operations

## Metrics

### Application
- Request rate: identifies changes in traffic.
- HTTP error rate: highlights failed requests.
- Request latency: shows slow responses.
- Backend availability: detects outages.

### Host
- CPU usage: identifies sustained compute pressure.
- Memory usage: detects resource exhaustion.
- Disk usage: helps prevent failures caused by full storage.
- Uptime and restarts: indicate instability or unexpected recovery.

### Containers
- Container health and restart count help identify crashes and failed deployments.

## Logs

Review:
- Application logs and stack traces.
- Container startup and health-check failures.
- Jenkins build and deployment logs.
- SSM command output.
- RDS events and relevant AWS infrastructure events.

Never print credentials, tokens, database passwords, or secret values in logs.

## Alerts

The assessment requires at least two meaningful alerts. The included rules cover:
- Backend target unavailable for two minutes.
- Host CPU usage above 85 percent for ten minutes.

Configure Alertmanager and a notification receiver to deliver alerts. Add additional alerts only when the underlying metrics are available and actionable.

## Avoiding alert noise

Use sustained thresholds rather than alerting on a single transient failure. Avoid alerts for normal short-lived CPU spikes, individual successful deployments, or expected container restarts during a release.

## Early detection

Use a combination of:
- Regular Prometheus scraping.
- Grafana dashboards.
- Health checks after deployment.
- Container logs and restart information.
- RDS monitoring and backup status.
- A documented response and rollback procedure.

## Operational checks

After deployment:
1. Confirm both containers are running and healthy.
2. Verify the backend can connect to RDS.
3. Confirm Prometheus can scrape the application and host metrics.
4. Check Grafana panels for populated metrics.
5. Review alerts and deployment logs.
