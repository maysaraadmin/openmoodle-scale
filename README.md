# OpenMoodleScale

Open-source deployment blueprint for running Moodle at scale with Kubernetes, OpenTofu, Ansible, Redis, PostgreSQL, MinIO, and observability tooling.

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
 | PostgreSQL| | Redis   | | MinIO  |          |
 |Primary | |Cluster  | |(S3)    |          |
 |+Replica| |(Sentinel| |        |          |
 +---+---+ |recommended| +--------+          |
           |for sessions)                    |
           +---------+----------------------+
         |    Prometheus + Grafana + Alerts  |
         |    Fluent Bit (centralized logs)  |
         +----------------------------------+

```

**Note:** For session storage, Redis Sentinel is recommended over Redis Cluster. Sentinel provides lower latency for session reads/writes and simpler operational model. Redis Cluster is better suited for sharding large datasets, not for session storage.

## Prerequisites

- **OpenTofu >= 1.6** with libvirt provider
- **Ansible >= 2.15** with `community.general`, `ansible.posix` collections
- **Helm >= 3.12**
- **kubectl** configured for the target cluster
- **Docker** for image builds
- **MinIO client (mc)** for backup offsite
- **Git Bash or WSL** on Windows (Makefile uses bash syntax)
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
2. **TLS** — Set `ingress.tls` with valid hosts and secretName, or use cert-manager. If enabling HSTS `preload`, verify eligibility at https://hstspreload.org first (valid certificate, HTTP-to-HTTPS redirect, no mixed content, etc.).
3. **Secrets** — Either set `secrets.existingSecret` to a pre-created secret, or set `secrets.create=true` and provide non-empty passwords.
4. **Database** — Set `database.host` to the PostgreSQL service name if using an external DB.
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
export DB_POD=$(kubectl get pod -n moodle-prod -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')
export APP_POD=$(kubectl get pod -n moodle-prod -l app.kubernetes.io/name=openmoodle -o jsonpath='{.items[0].metadata.name}')
export SECRET_NAME=openmoodle-postgresql
export DB_PASSWORD="$(kubectl get secret -n moodle-prod $SECRET_NAME -o jsonpath='{.data.password}' | base64 -d)"
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
- PostgreSQL connections
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
| MoodleDBCritical | critical | PostgreSQL connections > 150 |
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
kubectl exec -n moodle-prod <postgresql-pod> -- psql -U moodle -c "SELECT * FROM pg_stat_activity;"
kubectl get pods -n moodle-prod -l app.kubernetes.io/name=postgresql
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
- Pod Security Admission enforced at `restricted` level
- NetworkPolicy restricts traffic to ingress controller and required backends
- Secrets should be managed via External Secrets Operator or Vault in production
- Image scanning runs in CI before deployment with Trivy
- Images are signed with cosign in the CI/CD pipeline
- Redis authentication is enabled via chart values
- PostgreSQL passwords are no longer committed to source control
- UFW firewall enabled on all nodes with only SSH, k8s API, and kubelet allowed
- Unattended security upgrades enabled on all nodes
- Terraform state should be stored in an encrypted remote backend (S3 + DynamoDB)

## Secrets Management

For production, never store secrets in plaintext values files. Use one of:

- **External Secrets Operator (ESO)** — sync secrets from AWS SSM, HashiCorp Vault, or other providers into Kubernetes Secrets
- **HashiCorp Vault** — inject secrets directly into pods with Vault Agent Injector
- **Sealed Secrets** — encrypt secrets that can only be decrypted by the cluster controller

Example with ESO:
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

## Automated Backups

Production enables a Kubernetes CronJob (`backup.enabled: true`) that runs daily at 2 AM and:

- Dumps PostgreSQL with `--single-transaction`
- Archives `/var/moodledata`
- Retains backups for 30 days (configurable)
- Stores backups locally on the cluster PVC

For offsite storage, use the manual `scripts/backup.sh` with MinIO client (`mc`) to upload backups to S3-compatible storage.

Manual backup commands remain available for ad-hoc use.

## GitOps with ArgoCD

ArgoCD Application manifests are provided in `helm/openmoodle/argocd/`. Deploy them to enable:

- Automated sync from the main branch
- Drift detection and self-healing
- Visual deployment history and rollback
- Promotion workflows between staging and production

## Service Mesh with Istio and Kiali

OpenMoodleScale includes optional Istio service mesh integration for observability, traffic management, and security.

### Installation

Install Istio and Kiali via Ansible:

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml --tags istio
```

This installs:
- **Istio Base** — CRDs and cluster-wide resources
- **Istiod** — Control plane (Pilot, Citadel, Galley)
- **Kiali** — Service mesh observability dashboard (accessible at the node IP on port 20001)

### Enabling Istio for Moodle

Enable Istio in your Helm values:

```yaml
# values-prod.yaml
istio:
  enabled: true

kiali:
  enabled: true
  externalUrl: "http://<master-node-ip>:20001"
```

The namespace will automatically be labeled for sidecar injection (`istio-injection=enabled`).

### What Kiali Provides

- **Traffic Topology** — Visual map of all services, workloads, and dependencies
- **Request Tracing** — Distributed tracing to identify latency bottlenecks (e.g., "why is the gradebook slow?")
- **Health Dashboard** — Real-time status of all services in the mesh
- **Traffic Management** — Visualize and configure routing rules, timeouts, and retries
- **Security** — View mTLS status and authorization policies

### Accessing Kiali

After installation, access Kiali at:

```
http://<master-node-ip>:20001/kiali
```

For production, configure an Ingress or port-forward:

```bash
kubectl port-forward -n kiali svc/kiali-server 20001:20001
```

### Istio Compatibility Notes

- Sidecar injection adds ~100MB memory overhead per pod
- Existing NetworkPolicies remain compatible with Istio
- HPA metrics still function normally with Istio sidecars
- VirtualService and DestinationRule templates are included in the Helm chart when `istio.enabled: true`

## Terraform Remote Backend

For production, configure a remote backend in `tofu/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "openmoodle-terraform-state"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "openmoodle-terraform-locks"
  }
}
```

Initialize the backend:
```bash
cd tofu
tofu init -migrate-state
```

## Database Connection Pooling

For high-traffic deployments, consider adding a connection pooler like ProxySQL or MaxScale between Moodle and PostgreSQL to reduce connection overhead during traffic spikes.

## PodDisruptionBudgets

PDBs are configured for all stateful components to ensure availability during cluster maintenance:

- **Moodle app** — minAvailable: max(1, replicas - 1)
- **PostgreSQL primary** — minAvailable: 1 (replicas cannot be drained below 1)
- **Redis** — minAvailable: 1

This prevents voluntary disruptions from taking down critical stateful pods.

## Pod Anti-Affinity

Stateful components are configured with pod anti-affinity to spread across separate nodes:

- PostgreSQL primary pods avoid scheduling on the same node
- Redis pods avoid scheduling on the same node
- This improves availability during node failures

## Security Policies with Kyverno

Kyverno policies are provided in `policies/kyverno/` to enforce security guardrails:

- **disallow-privileged-containers** — No privileged containers allowed
- **require-run-as-non-root** — All containers must run as non-root
- **require-read-only-root-filesystem** — Root filesystem must be read-only
- **disallow-host-path** — HostPath mounts are blocked
- **require-resource-limits** — CPU and memory limits are mandatory

Install policies:
```bash
kubectl apply -f policies/kyverno/
```

Policies run in `Enforce` mode, blocking non-compliant pods at admission time.

## Encrypted Backups

Enable backup encryption in production to protect data at rest:

```yaml
backup:
  encryption:
    enabled: true
```

Set the encryption key via Helm values or an external secret:
```bash
helm upgrade ... --set secrets.backupEncryptionKey="your-strong-passphrase"
```

Backups are encrypted with AES-256 using GPG symmetric encryption before retention cleanup.

## CI/CD Pipeline

The Jenkins pipeline includes:

1. **Lint** — yamllint, terraform fmt check
2. **Validate** — helm dependency build, helm lint, helm template, Docker build
3. **Security Scan** — Trivy scan for HIGH/CRITICAL CVEs
4. **Sign Images** — cosign signs images with keyless provenance (main branch only)
5. **Publish** — Push images and capture repo digests
6. **Load Test** — k6 smoke test against staging covering login, course pages, static assets, and API endpoints
7. **Deploy** — Helm upgrade to production with digest-pinned tags

## Monitoring

Access Grafana at the ingress host. The `OpenMoodleScale Overview` dashboard includes:

- HTTP request rate and p95 latency
- Moodle app CPU and memory
- PostgreSQL connections
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
| MoodleDBCritical | critical | PostgreSQL connections > 150 |
| MoodleRedisDown | critical | Redis unreachable for 2m |
| MoodleCertExpirySoon | warning | TLS cert expires within 7 days |
| MoodleNginxUpstreamErrors | critical | Upstream 5xx errors |

## Logging

Fluent Bit runs as a DaemonSet in `kube-system`, tailing container logs and shipping JSON to stdout. Configure Fluent Bit outputs in `monitoring/fluent-bit/configmap.yaml` to forward logs to Loki, Elasticsearch, Splunk, or other aggregators.

## Troubleshooting

### Pods won't start after deploy

```bash
kubectl describe pod -n moodle-prod -l app.kubernetes.io/name=openmoodle
kubectl logs -n moodle-prod <pod-name> -c moodle-app
```

### Database connection failures

```bash
kubectl exec -n moodle-prod <postgresql-pod> -- psql -U moodle -c "SELECT * FROM pg_stat_activity;"
kubectl get pods -n moodle-prod -l app.kubernetes.io/name=postgresql
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

### Backup job failing

```bash
kubectl get cronjob -n moodle-prod openmoodle-prod-openmoodle-backup
kubectl get job -n moodle-prod -l app.kubernetes.io/name=openmoodle
kubectl logs -n moodle-prod <backup-job-pod>
```

## Contributing

1. Fork and create a feature branch
2. Run `make lint` before committing
3. Validate with `helm template` against both staging and prod values
4. Run `helm test openmoodle-prod --namespace moodle-prod` after deployment
5. Submit a PR

## License

MIT. See LICENSE for details.
