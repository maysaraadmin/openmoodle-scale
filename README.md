# OpenMoodleScale

Open-source deployment blueprint for running Moodle at large scale with Kubernetes, OpenTofu, Ansible, Redis, MariaDB, MinIO, Longhorn, and observability tooling.

This repository is an infrastructure starting point, not a capacity guarantee. Validate sizing, Moodle compatibility, database topology, object storage integration, security, and recovery objectives in staging before production use.

## Deploy

```bash
helm dependency build helm/openmoodle
helm lint helm/openmoodle
helm upgrade --install openmoodle-prod helm/openmoodle --namespace moodle-prod --create-namespace --wait
```

Set private registry, hostname, storage class, and credentials for your environment. Project configuration is MIT licensed; third-party components retain their own licenses.

## Required production values

The chart intentionally fails closed unless `ingress.tls` is configured. Supply an external secret through `secrets.existingSecret`, or explicitly set `secrets.create=true` with non-empty credentials in a protected values file. Do not commit credentials or deploy the example values file unchanged.

Before production, verify the MariaDB service name, configure database and Moodledata replication, and test restore procedures. The backup scripts require `DB_POD`, `APP_POD`, `SECRET_NAME`, and `DB_PASSWORD`; they create a MariaDB dump and Moodledata archive, but object storage and volume snapshots must be protected separately.