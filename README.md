# Demo Factory

GitOps system for provisioning isolated CloudNext demo environments on a k3d Kubernetes cluster. Each client gets their own namespace with a full application stack (backend, frontend, PostgreSQL, MinIO).

## Architecture

- **Source of truth**: Individual YAML files in `demos/clients/{slug}.yaml`
- **ArgoCD ApplicationSet**: Reads client files, creates one Application per client
- **Helm chart**: `charts/demo-stack/` deploys the full stack to namespace `demo-{slug}`
- **KEDA http-add-on**: Scale-to-zero after 15 min idle, wake on first HTTP request
- **Expiry**: GitHub Action runs daily, opens a PR to remove expired demos
- **Domain**: `demo-{slug}.lab.cloudtsl.com` (TLS via Traefik / Let's Encrypt on lab-proxy)

## Stack per demo

| Component   | Image / Version                                    | Kind         |
| ----------- | -------------------------------------------------- | ------------ |
| Backend     | ghcr.io/cloud-tsl/cloud-next:backend-X.Y.Z (.NET 10 API) | Deployment   |
| Frontend    | ghcr.io/cloud-tsl/cloud-next:frontend-X.Y.Z (Angular 21 on nginx) | Deployment   |
| PostgreSQL  | postgres:17-alpine                                 | StatefulSet  |
| MinIO S3    | minio/minio                                        | StatefulSet  |

## Tiers

| Tier    | Backend        | Frontend       | Storage | Quota                          |
| ------- | -------------- | -------------- | ------- | ------------------------------ |
| `small` | 50m / 96Mi     | 25m / 32Mi     | 512Mi   | 1 CPU / 1Gi RAM / 10 pods     |
| `large` | 100m / 192Mi   | 50m / 64Mi     | 2Gi     | 2 CPU / 2Gi RAM / 15 pods     |

## Client file format

```yaml
# demos/clients/acme-corp.yaml
slug: acme-corp
tier: small
expiresAt: "2026-05-15"
seedData: default
```

## Quick start

### Prerequisites

- kubectl access to the k3d cluster
- GitHub CLI (`gh`) authenticated
- Python 3 with PyYAML (`pip install pyyaml`)
- ArgoCD ApplicationSet applied (one-time setup -- see [Bootstrap](#bootstrap-one-time-setup))

### Create your first demo

```bash
./scripts/new-demo.sh acme-corp small 30
# Creates demos/clients/acme-corp.yaml, commits, pushes
# ArgoCD picks up within ~3 minutes
# Access at https://demo-acme-corp.lab.cloudtsl.com
```

### Extend a demo

```bash
./scripts/extend-demo.sh acme-corp 14
# Extends expiry by 14 days
```

### List all demos

```bash
./scripts/list-demos.sh
# Shows table with slug, tier, expiry, days left, k8s status
```

### Remove a demo manually

```bash
git rm demos/clients/acme-corp.yaml
git commit -m "demo: remove acme-corp"
git push
# ArgoCD deletes the namespace and all resources
```

## How expiry works

1. GitHub Action runs daily at 06:00 UTC.
2. Checks each client file's `expiresAt` date.
3. If expired: deletes the file, opens a PR.
4. You review and merge (or enable auto-merge).
5. ArgoCD sees the file is gone, deletes the Application, and prunes the namespace.

## Scale-to-zero (KEDA)

- Frontend deployment scales to 0 replicas after 15 minutes of no HTTP traffic.
- Backend stays at 1 replica (avoids cascading cold-start delays).
- First request after idle: KEDA interceptor holds the request, scales frontend up (~2-3 s), then proxies through.
- PostgreSQL and MinIO always run (StatefulSets, not scaled).

## Debugging

### Demo not starting

```bash
# Check ArgoCD sync status
kubectl get app -n argocd | grep demo-

# Check pod status
kubectl get pods -n demo-{slug}

# Check events
kubectl get events -n demo-{slug} --sort-by=.lastTimestamp

# Check backend logs
kubectl logs -n demo-{slug} deployment/backend
```

### Demo shows 503

Likely KEDA scaling -- the frontend is at 0 replicas and the interceptor is waking it up. Wait 3-5 seconds and refresh.

```bash
# Check frontend replicas
kubectl get deployment frontend -n demo-{slug}

# Check KEDA scaled object
kubectl get httpscaledobject -n demo-{slug}
```

### Database issues

```bash
# Connect to postgres
kubectl exec -it -n demo-{slug} postgres-0 -- psql -U demo -d demo

# Check PVC
kubectl get pvc -n demo-{slug}
```

## Adding a new seed dataset

Seed data support is planned (see GitHub Issues). Currently all demos start with an empty database (schema only via EF Core migrations).

## Updating the app version

Edit `charts/demo-stack/values.yaml`:

```yaml
images:
  backend:
    tag: backend-0.2.0
  frontend:
    tag: frontend-0.2.0
```

Commit and push. ArgoCD will rolling-update all active demos.

To update a single demo without affecting others: override the image tag in the client file (not yet supported -- requires chart enhancement).

## Helm upgrade strategy

The chart uses `RollingUpdate` strategy by default. When you change chart templates:

1. All active demos get updated on next ArgoCD sync.
2. ArgoCD respects `selfHeal: true` -- manual changes in cluster are reverted.
3. To test changes safely: create a test demo first, verify, then push to main.

## Repository structure

```
demo-factory/
├── argocd/
│   └── applicationset.yaml      # ArgoCD ApplicationSet (apply once)
├── charts/
│   └── demo-stack/              # Helm chart for full stack
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── backend.yaml
│           ├── frontend.yaml
│           ├── postgres.yaml
│           ├── minio.yaml
│           ├── ingress.yaml
│           ├── keda.yaml
│           ├── keda-interceptor-svc.yaml
│           ├── networkpolicy.yaml
│           ├── resourcequota.yaml
│           └── ghcr-pull-secret.yaml
├── demos/
│   └── clients/                 # One YAML per client
│       └── example.yaml
├── scripts/
│   ├── new-demo.sh
│   ├── extend-demo.sh
│   ├── list-demos.sh
│   └── update_clients.py
├── .github/
│   └── workflows/
│       └── expire-demos.yml
└── README.md
```

## Bootstrap (one-time setup)

### 1. Add repo to ArgoCD

```bash
# Create GitHub PAT scoped to Cloud-TSL/demo-factory (read)
# Add as ArgoCD repository secret
kubectl create secret generic demo-factory-repo \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/Cloud-TSL/demo-factory.git \
  --from-literal=username=x-access-token \
  --from-literal=password=YOUR_GITHUB_PAT

kubectl label secret demo-factory-repo -n argocd argocd.argoproj.io/secret-type=repository
```

### 2. Apply ApplicationSet

```bash
kubectl apply -f argocd/applicationset.yaml
```

### 3. GHCR pull secret

The chart needs a GitHub PAT to pull images from ghcr.io/cloud-tsl. Set `ghcrToken` in `values.yaml` or pass it via ArgoCD.

## Monitoring

A Grafana dashboard "Demo Factory" is available showing:

- Active demos count, scaled-to-zero count
- CPU / Memory usage per demo namespace
- Frontend / Backend replica counts (KEDA scaling visibility)
- Per-demo resource table
