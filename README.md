# INT333: Web Service Configuration Enforcement and Uptime Monitoring with Controlled Recovery

## DevOps Tools Used
- **Nginx (Dockerized):** Web service serving `/` and `/health` on port `8080`.
- **Puppet (`manifests/site.pp`):** Declarative manifest for package, config file, and service state enforcement.
- **Bash Monitoring & Recovery Script (`scripts/monitor_recover.sh`):** Health checks, SHA-256 config drift detection, and automated recovery.
- **GitHub Actions (`.github/workflows/devops-check.yml`):** Automated syntax and Nginx config validation on push.
