# OpenMoodleScale

Open-source deployment blueprint for running Moodle at scale with Kubernetes, OpenTofu, Ansible, Redis, MariaDB, MinIO, and observability tooling.

## Architecture

```
                    +------------------+
                    |   Ingress NGINX  |
                    +--------+---------+
                             |
                    +--------+---------+
                    |     Varnish       |
                    |  (optional cache) |
                    +--------+---------+
                             |
               +-------------+-------------+
               |                           |
        +------+------+           +--------+--------+
        | Moodle App  |           |   Moodle Web     |
        | PHP-FPM x N |           |   Nginx x N      |
        +------+------+           +------------------+
               |                           |
        +------+------+                    |
        |   Shared    |                    |
        | Persistent  |                    |
        |   Volume    |                    |
        | (moodledata)|                    |
        +------+------+                    |
               |                           |
    +----------+----------+                |
    |          |          |                |
+---+---+ +----+----+ +--+-----+          |
| MariaDB| | Redis   | | MinIO  |          |
|Primary | |Cluster  | |(S3)    |          |
|+Replica| |         | |        |          |
+---+---+ +---------+ +--------+          |
                                           |
        +----------------------------------+
        |    Prometheus + Grafana + Alerts  |
        |    Fluent Bit (centralized logs)  |
        +----------------------------------+

```

## Prerequisites

- **OpenTofu >= 1.6** with libvirt provider
- **Ansible >= 2.15** with `community.general`, `ansible.posix` collections
- **Helm >= 3.12**
- **kubectl** configured for the target cluster
- **Docker** for image builds
- **MinIO client (mc)** for backup offsite
- A private container registry reachable from the cluster
- At least 3 nodes (1 control-plane, 2 workers) with:
  - 16 GB RAM, 4 vCPU each
  - 50 GB disk per node minimum
  - libvirt or equivalent virtualization

## Quick Start

### 1. Provision Infrastructure

```bash
make plan
make apply
```

This creates libvirt VMs with cloud-init, injecting your SSH key.

### 2. Bootstrap Kubernetes

```bash
make k8s
```

Ansible configures sysctl, containerd, installs kubeadm/kubelet/kubectl, and joins workers.

### 3. Build and Push Images

```bash
export IMAGE_TAG=$(git rev-parse --short HEAD)
docker build -t registry.openmoodle.local/openmoodle/moodle-app:${IMAGE_TAG} -f docker/moodle/Dockerfile docker/moodle
docker build -t registry.openmoodle.local/openmoodle/moodle-nginx:${IMAGE_TAG} -f docker/nginx/Dockerfile docker/nginx
docker push registry.openmoodle.local/openmoodle/moodle-app:${IMAGE_TAG}
docker push registry.openmoodle.local/openmoodle/moodle-nginx:${IMAGE_TAG}
```

### 4. Deploy Staging

```bash
cp helm/openmoodle/values-staging.yaml helm/openmoodle/values-staging-local.yaml
# Edit values-staging-local.yaml with your registry, passwords, and TLS secrets
make deploy-staging
```

### 5. Deploy Production

```bash
cp helm/openmoodle/values-prod.yaml helm/openmoodle/values-prod-local.yaml
# Edit values-prod-local.yaml with production values
make deploy-prod
```

## Configuration

### Environment Files

Create environment-specific overrides and keep them out of version control:

| File | Purpose |
|------|---------|
| `helm/openmoodle/values.yaml` | Base defaults |
| `helm/openmoodle/values-staging.yaml` | Staging overrides |
| `helm/openmoodle/values-prod.yaml` | Production overrides |

### Critical Settings

Before deploying to production, configure:

1. **Registry** — Set `global.imageRegistry` to your private registry.
2. **TLS** — Set `ingress.tls` with valid hosts and secretName, or use cert-manager.
3. **Secrets** — Either set `secrets.existingSecret` to a pre-created secret, or set `secrets.create=true` and provide non-empty passwords.
4. **Database** — Set `database.host` to the MariaDB service name if using an external DB.
5. **Redis auth** — Set `redis.auth.password` and `secrets.redisPassword`.
6. **MinIO / S3** — If using object storage, set `fileStorage.enabled=true` and S3 credentials.

## Deployment Targets

| Target | Command | Replicas | HPA Max |
|--------|---------|----------|---------|
| Staging | `make deploy-staging` | 2 | 5 |
| Production | `make deploy-prod` | 5 | 50 |

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make plan` | Run OpenTofu plan |
| `make apply` | Apply OpenTofu infrastructure |
| `make k8s` | Bootstrap Kubernetes with Ansible |
| `make deploy-staging` | Deploy staging environment |
| `make deploy-prod` | Deploy production environment |
| `make lint` | Lint Helm charts and templates |
| `make destroy` | Destroy libvirt infrastructure |

## Backup and Restore

### Backup

```bash
export DB_POD=$(kubectl get pod -n moodle-prod -l app.kubernetes.io/name=mariadb -o jsonpath='{.items[0].metadata.name}')
export APP_POD=$(kubectl get pod -n moodle-prod -l app.kubernetes.io/name=openmoodle -o jsonpath='{.items[0].metadata.name}')
export SECRET_NAME=openmoodle-prod-openmoodle-secrets
export DB_PASSWORD="$(kubectl get secret -n moodle-prod $SECRET_NAME -o jsonpath='{.data.database-password}' | base64 -d)"
export MINIO_ACCESS_KEY="$(kubectl get secret -n moodle-prod $SECRET_NAME -o jsonpath='{.data.s3-access-key}' | base64 -d)"
export MINIO_SECRET_KEY="$(kubectl get secret -n moodle-prod $SECRET_NAME -o jsonpath='{.data.s3-secret-key}' | base64 -d)"
./scripts/backup.sh
```

### Verify Backup

```bash
./scripts/verify-backup.sh /backup/openmoodle-20260825-120000.tar.gz
```

This restores to a throwaway namespace and confirms the archive is valid.

### Restore

```bash
export DB_POD=...
export APP_POD=...
export DB_PASSWORD="..."
./scripts/restore.sh /backup/openmoodle-20260825-120000.tar.gz
```

## Monitoring

Access Grafana at the ingress host. The `OpenMoodleScale Overview` dashboard includes:

- HTTP request rate and p95 latency
- Moodle app CPU and memory
- MariaDB connections
- Redis connected clients and memory
- PVC usage
- Nginx active connections
- Pod restart count
- HPA replica count

### Alerts

| Alert | Severity | Condition |
|-------|----------|-----------|
| MoodleHighErrorRate | critical | HTTP 5xx rate > 5% for 5m |
| MoodlePodsCrashLooping | critical | App pod restarts > 0 for 15m |
| MoodleHighMemoryUsage | warning | Memory > 90% limit for 5m |
| MoodleHPAMaxedOut | warning | HPA at max replicas for 10m |
| MoodlePodPending | warning | Pods stuck in Pending for 5m |
| MoodlePVCUsageHigh | warning | PVC > 85% used for 5m |
| MoodleDBCritical | critical | MariaDB connections > 150 |
| MoodleRedisDown | critical | Redis unreachable for 2m |
| MoodleCertExpirySoon | warning | TLS cert expires within 7 days |
| MoodleNginxUpstreamErrors | critical | Upstream 5xx errors |

## Logging

Fluent Bit runs as a DaemonSet in `kube-system`, tailing container logs and shipping JSON to stdout. Connect a log aggregator (Loki, Elasticsearch, Splunk) to the Fluent Bit output.

## CI/CD

Jenkins pipeline stages:

1. **Lint** — yamllint, terraform fmt check
2. **Validate** — helm dependency build, helm lint, helm template, Docker build
3. **Security Scan** — Trivy scan for HIGH/CRITICAL CVEs
4. **Publish** — Push images and capture repo digests
5. **Load Test** — k6 smoke test against staging
6. **Deploy** — Helm upgrade to production with digest-pinned tags

## Troubleshooting

### Pods won't start after deploy

```bash
kubectl describe pod -n moodle-prod -l app.kubernetes.io/name=openmoodle
kubectl logs -n moodle-prod <pod-name> -c moodle-app
```

### Database connection failures

```bash
kubectl exec -n moodle-prod <mariadb-pod> -- mariadb -u moodle -p -e "SHOW PROCESSLIST"
kubectl get pods -n moodle-prod -l app.kubernetes.io/name=mariadb
```

### Redis session issues

```bash
kubectl exec -n moodle-prod <redis-pod> -- redis-cli ping
kubectl logs -n moodle-prod <moodle-app-pod> | grep -i redis
```

### PVC not binding

```bash
kubectl get pvc -n moodle-prod
kubectl get storageclass
kubectl describe pvc -n moodle-prod openmoodle-prod-openmoodle-moodledata
```

## Security Notes

- All containers run as non-root with `readOnlyRootFilesystem: true`
- `allowPrivilegeEscalation: false` and `capabilities: drop [ALL]`
- NetworkPolicy restricts traffic to ingress controller and required backends
- Secrets should be managed via External Secrets Operator or Vault in production
- Image scanning runs in CI before deployment
- Redis authentication is enabled via chart values

## Contributing

1. Fork and create a feature branch
2. Run `make lint` before committing
3. Validate with `helm template` against both staging and prod values
4. Submit a PR

## License

MIT. See LICENSE for details.
