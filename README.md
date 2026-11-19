# Idea Board — Multi-Cloud DevOps Project

I built this project as a DevOps case study to practice taking a small full-stack application from local development through containerization and deployment planning.

The app lets people submit ideas and view the ones already saved. It uses React for the frontend, FastAPI for the API, and PostgreSQL for storage. I also prepared Docker, Kubernetes, Terraform, and GitHub Actions configuration for AWS and Google Cloud.

The application has been tested locally. The AWS and GCP infrastructure and deployment workflows are in the repository, but **I have not deployed either cloud environment or verified public URLs**.

## Architecture

```text
Browser
  └── Nginx serves the React app and forwards /api and /health
       └── FastAPI
            └── PostgreSQL

GitHub Actions
  ├── Tests and configuration checks
  ├── Builds and scans container images
  └── Optional, manually requested cloud deployment
       Terraform plan → approval → AWS or GCP resources
       Kubernetes rollout → app health check → optional Gemini report
```

I share the application and Kubernetes manifests between clouds, but keep separate Terraform configurations for AWS and GCP. Each provider has different networking, Kubernetes, database, and registry services. The workflow builds the app images once and copies them to the registry for the selected provider.

## Technologies I used

- **Frontend:** React 18, Vite, JavaScript, CSS
- **API and database:** FastAPI, Pydantic, SQLAlchemy, PostgreSQL
- **Containers and orchestration:** Docker, Docker Compose, Nginx, Kubernetes
- **Infrastructure as code:** Terraform with AWS and Google Cloud providers
- **Automation:** GitHub Actions for tests, image scanning, and optional deployment
- **Diagnostics:** Gemini API for an optional report after deployment
- **Tests:** Pytest and Node's built-in test runner

## Repository map

```text
backend/                 FastAPI app, database integration, and API tests
frontend/                React app, Nginx config, and frontend tests
terraform/environments/  AWS and GCP root configurations and example variables
terraform/modules/aws/   AWS networking, EKS, and RDS modules
terraform/modules/gcp/   GCP networking, GKE, and Cloud SQL modules
k8s/                     Shared namespace, ConfigMap, Deployments, Services, probes
ai/                      Gemini deployment report and helper tests
.github/workflows/       CI checks and optional cloud deployment workflow
docker-compose.yml       Local frontend, API, and database stack
```

When the backend starts, it creates the application tables from its SQLAlchemy models.

## Run locally

To run the app locally, install Docker Desktop and enable its Linux container engine.

1. Copy the example environment file:

   ```powershell
   Copy-Item .env.example .env
   ```

2. Build and start the application:

   ```powershell
   docker compose up --build -d
   ```

3. Check services and the database-backed health endpoint:

   ```powershell
   docker compose ps
   Invoke-RestMethod http://localhost:8000/health
   ```

4. On the same computer where Docker Compose is running, open [http://127.0.0.1:3000](http://127.0.0.1:3000), submit an idea, and check that it appears in the list. The backend stores it in PostgreSQL.

The API documentation is at [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs). The database is published on host port `5433` for local tools such as pgAdmin:

| pgAdmin field | Value |
|---|---|
| Host | `localhost` |
| Port | `5433` |
| Database | `ideas` |
| Username | `user` |
| Password | `password` (local development only) |

To inspect rows in PowerShell:

```powershell
docker compose exec db psql -U user -d ideas -c "SELECT id, content, created_at FROM ideas ORDER BY created_at DESC;"
```

To stop the containers while keeping the saved database data:

```powershell
docker compose down
```

`docker compose down -v` also removes the PostgreSQL volume and deletes local ideas. Use it only when you want to reset the database. The example credentials are for local development only; don't reuse them in a shared or production environment.

## API

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/ideas` | Return ideas newest first |
| `POST` | `/api/ideas` | Validate and store `{"content":"..."}` |
| `GET` | `/health` | Check API and database connectivity |
| `GET` | `/live` | Check that the API process is responsive |

The API trims idea content, rejects blank text, and limits it to 1,000 characters. `/health` returns HTTP 503 if the database is unreachable. Kubernetes uses `/live` to check that the API process is running and `/health` to check API/database readiness.

## Tests and local validation

Run the backend API and Gemini helper tests:

```powershell
python -m pip install -r backend/requirements-dev.txt
python -m pytest -q backend/tests ai/test_deployment_analyzer.py
```

By default, backend tests use a separate in-memory SQLite database. To test against a dedicated PostgreSQL test database, set `TEST_DATABASE_URL`. The tests do not use the app's `DATABASE_URL`. In CI, they run against a temporary PostgreSQL service.

Run frontend tests and build (Node.js 20+ required):

```powershell
Set-Location frontend
npm ci
npm test
npm run build
Set-Location ..
```

Render the Kubernetes resources without applying them:

```powershell
kubectl kustomize k8s
```

Terraform formatting and validation (Terraform 1.10+):

```powershell
terraform fmt -recursive terraform
Set-Location terraform/environments/aws
terraform init -backend=false
terraform validate
Set-Location ../gcp
terraform init -backend=false
terraform validate
Set-Location ../../..
```

These Terraform commands validate configuration; `terraform init -backend=false` and `terraform validate` do not create cloud resources. Before deployment, you still need provider access, available quotas, and a careful review of the actual plan and costs.

## Kubernetes

I use the manifests in `k8s/` to create the `idea-board` namespace, backend ConfigMap, frontend and backend Deployments, and Services. The frontend Service uses a cloud load balancer. Nginx forwards API and health requests to the internal backend Service. PostgreSQL is provided by the cloud database service; it is not a pod in this setup.

I leave the database Secret out of the Kustomize resource list. During deployment, the workflow creates `backend-secrets` from a sensitive Terraform output. `backend-secret.example.yaml` is only an example—don't apply its placeholder values.

### Local Kubernetes Deployment (Docker Desktop)

The optional `k8s/overlays/local/` configuration runs the app on a single-node Docker Desktop Kubernetes cluster. It adds a PostgreSQL pod with a persistent volume and applies local probe settings and one replica per app Deployment. It is separate from the base Kubernetes configuration above, which expects a cloud-managed PostgreSQL database.

Prerequisites:

- Docker Desktop with Kubernetes enabled and the `docker-desktop` context available.
- `kubectl` and access to the GHCR images referenced in `k8s/overlays/local/kustomization.yaml`.

Select and check the local cluster:

```powershell
kubectl config use-context docker-desktop
kubectl get nodes
```

Create the namespace before its local database Secret:

```powershell
kubectl apply -f .\k8s\namespace.yml
```

On a new local cluster, create `backend-secrets` with a randomly generated local-only password. This PowerShell command sends the Secret directly to Kubernetes and does not print the credential. Run it only once for a new database; if the Secret already exists, keep reusing it so its password stays consistent with the database on the persistent volume.

```powershell
$bytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$password = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
$rng.Dispose()
$secretJson = @{
    apiVersion = 'v1'
    kind = 'Secret'
    metadata = @{ name = 'backend-secrets'; namespace = 'idea-board' }
    type = 'Opaque'
    stringData = @{
        POSTGRES_PASSWORD = $password
        DATABASE_URL = "postgresql+psycopg2://user:$password@postgres:5432/ideas"
    }
} | ConvertTo-Json -Depth 5
$secretJson | kubectl apply -f -
Remove-Variable password, secretJson, bytes, rng
```

Render and apply the local configuration:

```powershell
kubectl kustomize --load-restrictor LoadRestrictionsNone .\k8s\overlays\local | kubectl apply -f -
kubectl rollout status deployment/postgres -n idea-board
kubectl rollout status deployment/backend -n idea-board
kubectl rollout status deployment/frontend -n idea-board
kubectl get deployments,pods,services,pvc -n idea-board
```

`--load-restrictor LoadRestrictionsNone` is required because the local overlay references shared manifests outside its directory. While Docker Desktop Kubernetes is running on your computer, open [http://127.0.0.1](http://127.0.0.1) in a browser on that same computer and check the API at [http://127.0.0.1/api/ideas](http://127.0.0.1/api/ideas). The IPv4 loopback address avoids `localhost` resolving to IPv6 on some systems. These links work only on a computer where the matching local app is running; they do not make the app public for other GitHub visitors. The local PostgreSQL PVC retains database data; do not delete it unless you intend to remove that data. This demonstrates local Kubernetes only—it does not deploy to AWS or GCP or provide a public cloud URL.

The Docker Compose app at [http://127.0.0.1:3000](http://127.0.0.1:3000) and the Kubernetes app at [http://127.0.0.1](http://127.0.0.1) use separate PostgreSQL databases. Ideas created in one are not automatically copied to the other. GitHub stores this project's source and configuration, not the runtime ideas; the cloud deployment workflow has not been run to create a public app URL. A public link requires deploying the app to a publicly reachable host; AWS/GCP deployment is not currently completed.

## Terraform and cloud setup

The Terraform code describes the network, managed Kubernetes cluster, private PostgreSQL database, and container registry for each cloud:

- **AWS:** public load-balancer subnets, private EKS worker/database subnets, per-AZ NAT gateways, EKS, private RDS PostgreSQL, and ECR repositories.
- **GCP:** VPC/subnets with Cloud NAT, private GKE nodes, Cloud SQL with private IP connectivity and backups, and Artifact Registry.

These resources can cost money: Kubernetes clusters, databases, load balancers, storage, and network traffic are **not guaranteed to be free**. Review the Terraform plan and current provider pricing before applying it. I have not created cloud resources for this project.

The example load balancer serves HTTP. Before using the app with real users, configure HTTPS/TLS and a domain.

### Cloud-agnostic design

I share the app images, API, Kubernetes Deployments and Services, health endpoints, and deployment stages. The AWS and GCP Terraform roots stay separate because their networking, Kubernetes, database, and registry services are not configured in the same way. The workflow selects a provider and passes it the required app settings and database credential. So the app is portable across the two setups, but switching clouds is more than changing one Terraform variable.

For AWS, I put the public load balancer in public subnets and EKS workers and RDS in private subnets. Each availability zone has a NAT gateway so private resources can make outbound connections. In GCP, GKE nodes use private addresses and Cloud NAT for outbound access. RDS and Cloud SQL are not intended to have public IP addresses.

### Cost estimate

These are rough planning estimates, **not quotes**. Actual prices depend on region, current provider rates, traffic, storage, discounts, and how long the resources run:

- **AWS:** roughly **$200–$350+ USD/month** for a continuously running small environment. The EKS control plane, two worker nodes, RDS, public load balancer, storage, and especially two NAT gateways all contribute; outbound traffic adds cost.
- **GCP:** roughly **$150–$300+ USD/month** for a continuously running small environment. The GKE cluster, two worker nodes, Cloud SQL, external load balancer, Cloud NAT, storage, and traffic contribute.

Running both environments continuously may therefore cost approximately **$350–$650+ USD/month**. Before approving a deployment, check the actual Terraform plan and use the providers' pricing calculators for your chosen region and configuration. When you no longer need an environment, review data retention and snapshots, then remove unused resources.

### Remote Terraform state bootstrap

Both Terraform roots store state remotely. Create the relevant state bucket before running `terraform init`:

```powershell
# AWS (choose a globally unique bucket name and update the S3 backend block)
aws s3api create-bucket --bucket YOUR_UNIQUE_TFSTATE_BUCKET --region us-east-1

# GCP (choose a globally unique bucket name and update the GCS backend block)
gcloud storage buckets create gs://YOUR_UNIQUE_TFSTATE_BUCKET --location=us-central1
```

Enable encryption and restrict access to the state bucket. Terraform state can contain database credentials even when variables and outputs are marked sensitive. Treat the state as secret data; never commit it.

Copy the example variables files and edit the non-secret settings. In particular, replace the example control-plane CIDR with your public IP address or trusted IP range:

```powershell
Copy-Item terraform\environments\aws\terraform.tfvars.example terraform\environments\aws\terraform.tfvars
Copy-Item terraform\environments\gcp\terraform.tfvars.example terraform\environments\gcp\terraform.tfvars
```

Don't put the database password in `terraform.tfvars`. Pass it through `TF_VAR_db_password` or a CI secret instead. The `terraform.tfvars.example` files are templates, not credentials.

### Manual AWS commands

After configuring AWS access, creating the state bucket, and checking the plan, the manual AWS workflow is:

```powershell
$env:TF_VAR_db_password = Read-Host "Database password (at least 16 characters)"
Set-Location terraform\environments\aws
terraform init
terraform plan
# Apply only after reviewing the plan and accepting the costs:
terraform apply
```

### Manual GCP commands

After authenticating with Google Cloud, enabling billing, creating the state bucket, and checking the plan, the manual GCP workflow is:

```powershell
$env:TF_VAR_db_password = Read-Host "Database password (at least 16 characters)"
$env:TF_VAR_project_id = Read-Host "GCP project ID"
Set-Location terraform\environments\gcp
terraform init
terraform plan
# Apply only after reviewing the plan and accepting the costs:
terraform apply
```

Cloud SQL uses private VPC connectivity and is not intended to be exposed publicly. Both database configurations enable backups: RDS has seven-day retention and a final snapshot, while Cloud SQL has point-in-time recovery.

## GitHub Actions workflow

I set up [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) to automate the checks and make deployment an explicit choice:

1. On pull requests and pushes, it runs the API tests against PostgreSQL, frontend tests and build, Python syntax checks, Terraform formatting and validation, and Kubernetes rendering.
2. On pushes to `main`, it builds the images, scans for critical and high vulnerabilities, and publishes versioned images to GHCR.
3. A manual run lets me select AWS or GCP. If I request infrastructure approval, the workflow creates a Terraform plan, shows it in the run summary, and saves that exact plan as an artifact for one day.
4. The apply/deploy job waits for approval in the matching protected GitHub Environment. It applies the saved plan, copies the images to ECR or Artifact Registry, updates Kubernetes, and checks rollouts and `/health`.
5. If rollout or the deterministic application/database health check fails, the workflow attempts to roll back the workloads. Gemini reports do not approve deployments or trigger rollbacks.

### Container security scanning

The workflow uses Trivy to scan both container images for CRITICAL and HIGH vulnerabilities before publishing them.

- `ignore-unfixed: true` excludes vulnerabilities without an available fix from the scan's failure gate.
- Fixable CRITICAL and HIGH findings still fail the workflow.
- The backend scan excludes pip's bundled `pip/_vendor/bom.cdx.json` file because its vendored package metadata can be older than the installed package version.

Vulnerability scanning remains enabled and gates image publishing.

Before using the cloud workflow, configure the secrets in `plan-aws`/`plan-gcp` for planning and in the corresponding protected `production-aws`/`production-gcp` environments for apply. Restrict the plan environments to trusted branches and configure required reviewers for both production environments. Configure each cloud's identity provider to trust GitHub's OIDC issuer and limit access to this repository and its matching GitHub Environment:

- `DB_PASSWORD` — strong database password, at least 16 characters
- AWS environments: `AWS_ROLE_ARN` for a role trusted for GitHub OIDC; give the plan role cloud read permissions plus S3 state read and lock-object create/delete access, and give the production role only the required apply/deploy permissions.
- GCP environments: `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT`, `GCP_PROJECT_ID`; grant the federated principal only the permissions needed for Terraform and deployment.
- Optional AI report: `GEMINI_API_KEY` in the matching production environment only

The required Actions variables are `AWS_EKS_API_CIDR` and `GCP_GKE_API_CIDR`. Set each to the trusted, stable public egress CIDR used by the deployment runner. The plan and apply jobs can use different hosted runners, so a temporary runner IP from the plan cannot safely be assumed for apply. Optional region variables are `AWS_REGION` (default `us-east-1`) and `GCP_REGION` (default `us-central1`). Grant each identity only the permissions it needs. Create the remote state buckets before Terraform initialization.

The workflow uses short-lived GitHub OIDC credentials rather than long-lived AWS keys or a downloaded GCP service-account key. Set up the provider-side OIDC trust and permissions before starting the plan jobs. The GCP planning identity needs provider read access and GCS state/lock access; production identities also need the narrowly scoped write permissions for the resources they manage.

To request a deployment, open **Actions → Test, Build, and Deploy → Run workflow**, choose a cloud, and select `yes` to request a plan. Review the plan in the Actions summary. Before apply, the matching protected GitHub Environment must approve the job. The apply job uses the saved plan artifact rather than generating a new one. That artifact contains a sensitive Terraform plan file, so keep repository and artifact access restricted. Selecting `no` skips the infrastructure plan and apply.

## Optional Gemini diagnostics

I added [`ai/deployment_analyzer.py`](ai/deployment_analyzer.py) to turn deployment status, health output, pod status, and recent logs into a short diagnostic report. It limits the input and redacts common secret-like values before sending it to Gemini.

The report may suggest causes and next steps for a person to review. It does not run commands, decide whether a deployment succeeded, approve Terraform, or roll back workloads. The workflow's Kubernetes rollout and database-backed `/health` checks determine deployment health. If Gemini is unavailable, those checks still decide the result.

To enable reports, add `GEMINI_API_KEY` to the matching production GitHub Environment. Logs may contain sensitive information, so review them before sending them to any external AI service.

## Deployment status

I haven't deployed this project to AWS or GCP, so there are no verified public application URLs yet. After a manually approved workflow completes, use the URL in its run summary and check it independently.

## Troubleshooting

- **Docker engine unavailable:** Start Docker Desktop with Linux containers enabled, then run `docker info`.
- **Backend cannot connect to PostgreSQL:** Check `docker compose ps` and `docker compose logs db backend`. Confirm the `.env` values match and give the database time to pass its health check.
- **Frontend reports API errors:** Check `docker compose logs frontend backend`. Nginx forwards `/api/` and `/health` to the backend.
- **Host port 5433 is occupied:** Change `POSTGRES_PORT` in `.env`, then recreate the database service.
- **Terraform cannot initialize:** Confirm the remote state bucket exists, your credentials can access it, and the bucket name in the environment's `main.tf` is correct.
- **Cloud deployment fails:** Review the workflow logs, Terraform plan/apply output, Kubernetes events, and pod logs. Before retrying, check whether the first attempt created any resources.

## Cloud cleanup

Removing cloud infrastructure is destructive and may delete application data. Back up anything you need, then review the destroy plan before proceeding.

```powershell
# AWS
Set-Location terraform\environments\aws
$env:TF_VAR_db_password = Read-Host "Database password used during provisioning"
# First change deletion_protection to false for the RDS instance in
# terraform/modules/aws/database/main.tf, then apply that setting change.
terraform apply
terraform plan -destroy
# Run only after reviewing all resources to be deleted:
terraform destroy
```

```powershell
# GCP
Set-Location terraform\environments\gcp
$env:TF_VAR_db_password = Read-Host "Database password used during provisioning"
$env:TF_VAR_project_id = Read-Host "GCP project ID"
# First change deletion_protection to false for the Cloud SQL instance in
# terraform/modules/gcp/database/main.tf, then apply that setting change.
terraform apply
terraform plan -destroy
# Run only after reviewing all resources to be deleted:
terraform destroy
```

The commands above first disable database deletion protection and then destroy the selected environment. Remove EKS/GKE, databases, registries, load balancers, and networking only when you intend to delete them. Keep remote state buckets until teardown is confirmed; if no longer needed, empty and delete them separately. Check provider billing after cleanup.

## What I learned

Building this project helped me connect application code to the systems that run it. I learned to keep the frontend, API, and database responsibilities separate; use health checks to distinguish “process is running” from “the app can reach its database”; and validate container and Kubernetes configuration before deployment.

I also learned that multi-cloud support does not mean pretending AWS and GCP are identical. I can share the application and Kubernetes layer, but the infrastructure needs provider-specific Terraform modules. Finally, a deployment pipeline needs deliberate controls: review the infrastructure plan, protect the apply step, keep credentials out of source, and use deterministic health checks to decide whether a rollout is healthy.
