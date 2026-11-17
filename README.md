# Idea Board — Cloud-Agnostic DevOps Platform

The Idea Board is a small React/FastAPI/PostgreSQL application with Docker-based local development and optional AWS/GCP deployment infrastructure. The infrastructure templates and CI workflows are designed for review before any cloud resources are created; **this repository does not claim that a public cloud deployment has already succeeded**.

## Architecture

```text
Browser
  └── Nginx (React static build; /api and /health proxy)
       └── FastAPI / Uvicorn
            └── PostgreSQL

GitHub Actions
  ├── Test API and frontend
  ├── Validate Terraform and build/scan images
  └── On an explicitly approved manual run:
       Terraform → EKS/RDS/ECR or GKE/Cloud SQL/Artifact Registry
       Kubernetes rollout → deterministic health check → optional Gemini report
```

AWS and GCP use their respective provider resources. The Kubernetes application manifests are shared, while each Terraform environment configures its own networking, managed database, cluster, and image registry. Container images are built once and copied to the selected provider registry for deployment.

## Technology

- React 18, Vite, JavaScript, and CSS
- FastAPI, Pydantic, SQLAlchemy, and PostgreSQL
- Docker, Docker Compose, Nginx, and Kubernetes
- Terraform with AWS and Google Cloud providers
- GitHub Actions for tests, image scanning, and opt-in deployment
- Gemini API for optional post-deployment explanations (not deployment approval)
- Pytest and Node's built-in test runner

## Repository map

```text
backend/                 FastAPI application, database integration, API tests
frontend/                React app, Nginx config, frontend tests
terraform/environments/  AWS and GCP root configurations and example variables
terraform/modules/aws/   AWS-specific networking, EKS, and RDS modules
terraform/modules/gcp/   GCP-specific networking, GKE, and Cloud SQL modules
k8s/                     Shared namespace, ConfigMap, Deployments, Services, probes
ai/                      Gemini deployment report and helper tests
.github/workflows/       CI validation and opt-in cloud deployment workflow
docker-compose.yml       Local three-service stack
```

On startup, the backend creates the application tables from its SQLAlchemy models.

## Run locally

Requirements: Docker Desktop with the Linux container engine enabled.

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

4. Open the app at [http://localhost:3000](http://localhost:3000). Submit an idea and it will be stored in PostgreSQL.

The API documentation is at [http://localhost:8000/docs](http://localhost:8000/docs). The database is published on host port `5433` for local tools such as pgAdmin:

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

To stop containers but retain saved database data:

```powershell
docker compose down
```

`docker compose down -v` removes the PostgreSQL data volume and deletes local saved ideas. Use it only when you intend to reset the local database. The default credentials are for local development and must not be used in a shared or production environment.

## API

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/ideas` | Return ideas newest first |
| `POST` | `/api/ideas` | Validate and store `{"content":"..."}` |
| `GET` | `/health` | Check API and database connectivity |
| `GET` | `/live` | Check that the API process is responsive |

Idea content is trimmed, must not be blank, and is limited to 1,000 characters. `/health` returns HTTP 503 when the database cannot be reached. Kubernetes uses `/live` for liveness and `/health` for readiness.

## Tests and local validation

Run backend API and Gemini helper tests:

```powershell
python -m pip install -r backend/requirements-dev.txt
python -m pytest -q backend/tests ai/test_deployment_analyzer.py
```

The backend tests use an isolated in-memory SQLite database by default. To run against a dedicated test PostgreSQL database, set `TEST_DATABASE_URL`; tests never use the application's `DATABASE_URL`. CI runs them against a temporary PostgreSQL service.

Run frontend tests and build (Node.js 20+ required):

```powershell
Set-Location frontend
npm ci
npm test
npm run build
Set-Location ..
```

Check rendered Kubernetes resources:

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

`terraform init -backend=false` and `terraform validate` do not create infrastructure. A Terraform plan is not a substitute for provider credentials, quotas, or reviewing actual costs.

## Kubernetes

The manifests in `k8s/` create the `idea-board` namespace, backend ConfigMap, backend/frontend Deployments, and services. The frontend is exposed through a cloud load balancer; Nginx forwards API and health requests to the internal backend Service. PostgreSQL is a managed cloud database, not another Kubernetes workload.

The database Secret is deliberately not included in the Kustomize resource list. Deployment automation creates `backend-secrets` from the sensitive Terraform output at runtime. `backend-secret.example.yaml` is documentation only; do not apply it with its placeholder values.

## Terraform and cloud setup

Terraform can create VPC networking, a managed Kubernetes cluster, private managed PostgreSQL, and a container registry:

- **AWS:** public load-balancer subnets, private EKS worker/database subnets, per-AZ NAT gateways, EKS, private RDS PostgreSQL, and ECR repositories.
- **GCP:** VPC/subnets with Cloud NAT, private GKE nodes, Cloud SQL with private IP connectivity and backups, and Artifact Registry.

Cloud resources can incur charges. EKS/GKE clusters, database instances, load balancers, storage, and network traffic are **not guaranteed to be free**. Review the plan and current provider pricing before applying. No cloud resources were created as part of this repository work.
The example load balancer serves HTTP; configure HTTPS/TLS and a domain before using it for real users.

### Cloud-agnostic design

The application images, API contract, Kubernetes Deployments/Services, health endpoints, and deployment stages are shared. AWS and GCP each have an independent Terraform root and provider-specific modules for the services that do not have identical cloud APIs (networking, managed Kubernetes, PostgreSQL, and image registries). The workflow selects one provider and supplies the same application-level settings and database credential to that provider's implementation. This is a practical multi-cloud adapter pattern; it is not a single Terraform configuration that can switch providers solely by changing one variable.

The AWS network uses public subnets for the internet-facing load balancer and private subnets for EKS workers and RDS. Each private subnet has a NAT gateway in its matching availability zone for outbound updates and registry access. GKE nodes use private addresses and Cloud NAT for outbound access. Cloud SQL and RDS are not intentionally assigned public IP addresses.

### Cost estimate

Treat these as planning ranges only, not quotes; exact prices depend on region, current provider rates, traffic, storage, discounts, and runtime:

- **AWS:** roughly **$200–$350+ USD/month** for a continuously running small environment. The EKS control plane, two worker nodes, RDS, public load balancer, storage, and especially two NAT gateways all contribute; outbound traffic adds cost.
- **GCP:** roughly **$150–$300+ USD/month** for a continuously running small environment. The GKE cluster, two worker nodes, Cloud SQL, external load balancer, Cloud NAT, storage, and traffic contribute.

Running both environments continuously may therefore cost approximately **$350–$650+ USD/month**. Use the actual Terraform plan and provider pricing calculators to estimate your selected region and configuration before approving deployment. Delete unused environments promptly, after reviewing the data-retention and snapshot impact.

### Remote Terraform state bootstrap

The Terraform roots use remote state, so create the state bucket before running `terraform init`:

```powershell
# AWS (choose a globally unique bucket name and update the S3 backend block)
aws s3api create-bucket --bucket YOUR_UNIQUE_TFSTATE_BUCKET --region us-east-1

# GCP (choose a globally unique bucket name and update the GCS backend block)
gcloud storage buckets create gs://YOUR_UNIQUE_TFSTATE_BUCKET --location=us-central1
```

Enable encryption and strict access controls on the state bucket. Terraform state contains sensitive database credentials even when outputs and variables are marked sensitive; protect state as a secret and do not commit it.

Copy the relevant example variables file and edit non-secret settings, including replacing the example control-plane CIDR with your public IP/range:

```powershell
Copy-Item terraform\environments\aws\terraform.tfvars.example terraform\environments\aws\terraform.tfvars
Copy-Item terraform\environments\gcp\terraform.tfvars.example terraform\environments\gcp\terraform.tfvars
```

Do not put the database password in `terraform.tfvars`; supply it through `TF_VAR_db_password` or a CI secret. The example `terraform.tfvars.example` files contain placeholders and are not deployment credentials.

### Manual AWS commands

After setting AWS credentials, creating the state bucket, and reviewing the plan:

```powershell
$env:TF_VAR_db_password = Read-Host "Database password (at least 16 characters)"
Set-Location terraform\environments\aws
terraform init
terraform plan
# Apply only after reviewing the plan and accepting the costs:
terraform apply
```

### Manual GCP commands

After authenticating with Google Cloud, enabling billing, creating the state bucket, and reviewing the plan:

```powershell
$env:TF_VAR_db_password = Read-Host "Database password (at least 16 characters)"
$env:TF_VAR_project_id = Read-Host "GCP project ID"
Set-Location terraform\environments\gcp
terraform init
terraform plan
# Apply only after reviewing the plan and accepting the costs:
terraform apply
```

The GCP Cloud SQL instance uses private VPC connectivity; it is not intentionally exposed to the public internet. Both database implementations enable backups; AWS RDS uses a seven-day retention period and a final snapshot, while Cloud SQL enables point-in-time recovery.

## GitHub Actions

The workflow at `.github/workflows/deploy.yml`:

1. Runs API tests using PostgreSQL, frontend tests/build, Python syntax checks, and Terraform format/validation.
2. Builds images, scans them for critical/high vulnerabilities, and publishes versioned images to GHCR on pushes to `main`.
3. For a manually selected cloud and `approve_infrastructure=yes`, creates and displays a Terraform plan, then saves the exact plan as a one-day workflow artifact. The apply/deploy job waits for approval from the corresponding protected GitHub Environment, downloads and applies that saved plan, copies images to ECR or Artifact Registry, updates Kubernetes, waits for rollouts, and checks `/health`.
4. Rolls back workloads if rollout or deterministic API/database health checks fail. Gemini output is advisory only and cannot approve or trigger rollback.

Before cloud deployment, configure these secrets in the `plan-aws`/`plan-gcp` environments for planning and in the matching protected `production-aws`/`production-gcp` environments for apply. Restrict the plan environments to trusted branches; configure required reviewers on both production environments. The cloud identity providers must trust GitHub's OIDC issuer and restrict the subject to this repository and the corresponding GitHub Environment:

- `DB_PASSWORD` — strong database password, at least 16 characters
- AWS environments: `AWS_ROLE_ARN` for a role trusted for GitHub OIDC; give the plan role cloud read permissions plus S3 state read and lock-object create/delete access, and give the production role only the required apply/deploy permissions.
- GCP environments: `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT`, `GCP_PROJECT_ID`; grant the federated principal only the permissions needed for Terraform and deployment.
- Optional AI report: `GEMINI_API_KEY` in the matching production environment only

Required Actions variables: `AWS_EKS_API_CIDR` and `GCP_GKE_API_CIDR`, each set to the trusted, stable public egress CIDR used by the deployment runner. The plan and apply run on different hosted runners, so a transient runner IP cannot safely be reused from the reviewed plan. Optional variables: `AWS_REGION` (default `us-east-1`) and `GCP_REGION` (default `us-central1`). Grant credentials only the permissions required to manage the intended resources. The remote state buckets must already exist before Terraform initialization.

The workflow uses short-lived GitHub OIDC credentials; it does not require long-lived AWS access keys or a downloaded GCP service-account key. Set up the provider-side OIDC trust and permissions before running the plan jobs. The GCP plan principal likewise needs provider read access and GCS state/lock access; production principals need the additional narrowly-scoped write permissions for the resources they manage.

To start a cloud deployment, open **Actions → Test, Build, and Deploy → Run workflow**, select a cloud, and choose `yes` to request a plan. Review the rendered plan in the Actions run summary before approving the apply job in the matching protected GitHub Environment. The apply job uses the saved plan artifact, not a newly generated plan. The artifact includes a sensitive Terraform plan file; restrict repository and artifact access. If `no` is selected, no infrastructure plan or apply runs.

## AI integration and Gemini deployment analysis

`ai/deployment_analyzer.py` submits a bounded set of deployment status, health response, pod status, and recent logs to Gemini. It redacts common secret-like values and limits input length. The resulting JSON report explains possible causes and suggests human-reviewed actions; it does not run shell commands, determine deployment success, or initiate rollback. The deterministic Kubernetes rollout and `/health` checks remain authoritative. If the Gemini key, package install, API, or response is unavailable, the deployment health result is still determined by those checks.

Set `GEMINI_API_KEY` in GitHub Secrets to enable reports. Review logs before sharing them with any external AI service.

The AI adds operational value by turning rollout observations and recent backend logs into a concise, structured diagnostic report for the human operator. It is intentionally not an autonomous infrastructure agent: it cannot run generated commands, approve Terraform, or affect deployment success or rollback. The deterministic Kubernetes rollout and database-backed health check remain the gate.

## Deployment URLs and status

No AWS or GCP deployment URL is listed here because successful public deployments have not been verified. After a successful manually approved workflow run, use the URL in that run's summary and verify it independently.

## Troubleshooting

- **Docker engine unavailable:** Start Docker Desktop and ensure it is using Linux containers, then run `docker info`.
- **Backend cannot connect to PostgreSQL:** Run `docker compose ps` and `docker compose logs db backend`; verify the `.env` values agree. Compose may need time for the database health check.
- **Frontend reports API errors:** Check `docker compose logs frontend backend`; Nginx proxies `/api/` and `/health`.
- **Host port 5433 is occupied:** Change `POSTGRES_PORT` in `.env`, then recreate the database service.
- **Terraform cannot initialize:** Confirm the remote state bucket exists, credentials can access it, and backend bucket names match the environment's `main.tf`.
- **Cloud deployment fails:** Inspect the workflow step logs, Terraform plan/apply output, Kubernetes events, and deployment logs. Do not retry an apply without checking whether resources were partially created.

## Cloud cleanup

Cloud teardown is destructive and may delete application data. First back up any data you need, then inspect the Terraform plan for destruction.

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

Destroy EKS/GKE, databases, registries, load balancers, and networking only when you intentionally want them removed. Remote state buckets are separate and should be retained until teardown is confirmed; empty and delete them separately if no longer needed. Review provider billing after cleanup.
