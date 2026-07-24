# Incident Post-Mortem — HTTP 5xx Errors

| Field | Details |
|---|---|
| Incident | 100 requests were sent to the App Service `/error` endpoint, generating HTTP 500 responses. |
| Start time | 24 July 2026 at approximately 15:25 CEST |
| Detection time | 24 July 2026 at 15:26 CEST |
| Impact | The `/error` endpoint returned HTTP 500 responses. The `/health` endpoint remained available. |
| Dashboard evidence | The HTTP 5xx Workbook panel and Grafana error panel displayed the increase. |
| Prometheus evidence | `increase(log_erreurs_total[5m])` reached `105.263`. |
| Alert | `HighApplicationErrorRate` fired with severity `1 — Error`. |
| Affected resource | `amw-hajar-mezouar-tf` |
| Detected instance | `app-hajar-mezouar-tf.azurewebsites.net`, job `log-analyser`. |
| Root cause | Controlled War Room requests were sent repeatedly to the `/error` endpoint. |
| Fix | Error-generating requests were stopped; no infrastructure repair was required. |
| Preventive action | Retain the alerts, review their thresholds, and investigate unexpected increases in HTTP 5xx responses. |
| Resolution | The alert returned to a healthy state after requests stopped and the rolling evaluation window elapsed. |
