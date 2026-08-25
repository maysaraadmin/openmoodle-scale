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