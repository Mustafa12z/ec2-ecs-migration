# Migration: EC2 → ECS Fargate

This document records how the legacy single-instance EC2 deployment was
migrated to a containerized, highly-available ECS (Fargate) architecture, the
cost of the new stack, and the trade-offs behind the decisions made along the
way.

## Why migrate

The EC2 stack (`terraform/ec2-app/`) had no autoscaling, no multi-AZ
resilience, no CI/CD, in-memory-only data (lost on every restart/redeploy),
and ran in a public subnet. See [`README.md`](README.md#legacy-limitations)
for the full list. None of this is acceptable for a production API.

## What changed

| Concern | Before (EC2) | After (ECS) |
|---|---|---|
| Compute | 1x EC2 instance, public subnet | ECS Fargate, 2–6 tasks, private subnets |
| Process management | systemd + Gunicorn | ECS service + CodeDeploy (blue/green) |
| Data | In-memory (Python dict), lost on restart | RDS PostgreSQL (Multi-AZ optional), Alembic-managed schema |
| Deploys | Manual SSH + `git pull` + service restart | GitHub Actions: build → Trivy scan → push → migrate → blue/green deploy |
| Networking | Public IP, security group only | ALB in public subnets, tasks + RDS in private subnets, HTTPS via ACM |
| Observability | Instance logs via `journalctl` | CloudWatch Logs, CPU/memory + ALB 5xx alarms |
| Secrets | Hardcoded / instance env | Secrets Manager, injected into the task at launch |
| Scaling | None (vertical only) | Target-tracking autoscaling on CPU (2–6 tasks) |
| Container topology | N/A | Sidecar: `nginx` (frontend, static + reverse proxy) + `api` (Flask/Gunicorn) in one task, sharing localhost |

## Migration steps taken

1. **Containerized both components** — `app/Dockerfile` (multi-stage, non-root user) and `frontend/Dockerfile` (nginx:alpine). Chose the **sidecar pattern** (both containers in one ECS task) over separate services, since nginx here is a thin reverse proxy + static-file server for a single API, not an independently-scaled edge layer.
2. **Decoupled ECR from the app stack** — `terraform/ecr/` is a standalone stack, applied once, before `terraform/ecs-app/` (which reads the repos via `data` sources). This avoids the chicken-and-egg problem where ECS needs an image to exist in ECR before the cluster/service can be created, while ECR-in-the-same-stack would need the cluster before an image could be pushed.
3. **Moved state to persistent storage** — replaced the EC2 app's in-memory dict with RDS PostgreSQL + SQLAlchemy, then further hardened with Alembic migrations and an app-factory pattern (see [Application Hardening](#application-hardening) below).
4. **Built the network** — dedicated VPC (`10.1.0.0/16`, distinct from the legacy `10.0.0.0/16`) with public subnets for the ALB and private subnets for ECS tasks + RDS. Single NAT gateway by default (cost trade-off, see below).
5. **Added a remote Terraform backend** — S3 + DynamoDB lock table (`terraform/ecs-app/backend.hcl.example`) so state isn't local-only.
6. **Wired TLS + DNS** — ACM certificate (DNS-validated) + existing Route53 hosted zone, ALB redirects HTTP→HTTPS.
7. **Built CI/CD** — GitHub Actions with OIDC (no long-lived AWS keys), Trivy image + IaC scanning (blocking on HIGH/CRITICAL fixable CVEs), SBOM generation, cosign keyless signing, a one-off ECS migration task (`alembic upgrade head && flask seed`) run **before** the blue/green cutover, then CodeDeploy handles the traffic shift.
8. **Kept the EC2 stack as a rollback path** — not destroyed immediately; decommissioned only after the ECS stack was validated in production.

## Application hardening (done alongside the infra migration)

Containerizing surfaced issues that wouldn't have mattered on a single
long-lived EC2 process:

- **Schema management**: added Alembic instead of ad-hoc `create_all()` — required because migrations must run predictably as part of a deploy pipeline, not as a side effect of importing the app.
- **App factory pattern**: `create_app()` builds a fresh SQLAlchemy engine per Gunicorn worker after fork, removing the need for `--preload` and eliminating a cold-start race against Postgres (`UniqueViolation` on concurrent `CREATE TABLE`).
- **Connection pool sizing**: made explicit and env-tunable, since `tasks × workers × pool` connections all compete for RDS's `max_connections` — invisible on a single EC2 box, critical once you can autoscale to 6 tasks.

## Cost estimate (eu-west-2, on-demand, approximate)

Pricing changes over time — treat this as a starting point and confirm with
the [AWS Pricing Calculator](https://calculator.aws) before budgeting.
Estimates assume the repo defaults: 2 tasks steady-state (0.5 vCPU / 1 GB
each), `db.t3.micro` single-AZ, one NAT gateway, minimal traffic.

| Resource | Configuration | Approx. monthly cost |
|---|---|---|
| ECS Fargate (compute) | 2 tasks × 0.5 vCPU / 1 GB, ~730 hrs | ~$30 |
| ECS Fargate (autoscale headroom) | up to 6 tasks under load | +$0–$60 (usage-based) |
| Application Load Balancer | 1 ALB, low traffic | ~$18 |
| NAT Gateway | 1 (single, not per-AZ) | ~$33 + data processing |
| RDS PostgreSQL | `db.t3.micro`, single-AZ, 20 GB gp3 | ~$15 |
| RDS (if Multi-AZ enabled) | `db.t3.micro` ×2 | ~$30 |
| Secrets Manager | 1 secret | ~$0.40 |
| CloudWatch Logs/Alarms | low volume | ~$2–5 |
| ECR storage | 2 repos, lifecycle-capped | ~$1 |
| Route53 | alias records only (zone assumed pre-existing) | $0 |
| ACM certificate | DNS-validated | $0 |
| **Total (steady-state, single-AZ RDS, single NAT)** | | **~$100–110/mo** |
| **Total (Multi-AZ RDS + autoscaled to max)** | | **~$180–220/mo** |

For comparison, the legacy EC2 stack was a single `t3.micro`/`t3.small`
instance (~$8–15/mo) with **no** ALB, NAT, or managed database — i.e. it was
cheap because it was missing the availability, security, and durability the
ECS stack now provides. The delta is the cost of removing the single point of
failure and the risk of unrecoverable data loss.

## Trade-offs and decisions

| Decision | Why | Trade-off accepted |
|---|---|---|
| Sidecar (nginx + api in one task) vs. separate services | Simpler networking (localhost between containers), one task definition, matches the existing "nginx in front of Flask" shape | Can't scale frontend and API independently; a bug in either container marks the whole task unhealthy |
| Single NAT gateway (not per-AZ) | ~$33/mo vs ~$66/mo for two | If the NAT's AZ fails, private-subnet egress (e.g. to ECR, Secrets Manager) breaks for tasks in the *other* AZ too, until Terraform is re-applied with `single_nat_gateway = false` |
| `db.t3.micro`, single-AZ by default | Matches expected low traffic; keeps cost down | No automatic failover on AZ outage; a Multi-AZ flip (`db_multi_az = true`) roughly doubles RDS cost |
| Blue/green via CodeDeploy (vs. rolling ECS deploys) | Instant rollback (traffic just points back at the old target group), safer for a service with a database migration step in front of it | More moving parts (CodeDeploy app, deployment group, two target groups) than a plain `ECS` rolling deployment controller |
| ECR as a separate Terraform stack | Solves the chicken-and-egg problem (ECS needs an image; you need a repo to push to) without manual `aws ecr create-repository` | One more stack to apply in the right order on a fresh account |
| Migrations as a one-off ECS `RunTask` in CI (not an init container) | Runs exactly once per deploy, not once per task launch/scale-out event; keeps Terraform infra-only | Adds a dependency step to the pipeline; if the AWS OIDC role's IAM permissions drift, migrations (and thus deploys) silently can't run — worth alerting on |
| GitHub OIDC instead of static AWS keys | No long-lived credentials to leak or rotate | Requires one-time IAM role + trust policy setup, and CI is only as available as GitHub Actions |
| Trivy gate blocks on HIGH/CRITICAL (fixable only) | Keeps known, patchable CVEs out of production images | `ignore-unfixed: true` means CVEs with no vendor patch yet don't block a deploy — a monitoring gap, not eliminated risk |
| Kept EC2 stack running post-migration (didn't tear down immediately) | Rollback path while validating ECS in production | Doubles infra spend during the overlap window (EC2 + ECS both running) |

## Rollback plan

If the ECS stack needs to be rolled back:

1. CodeDeploy blue/green keeps the previous task set's target group live for a configurable bake time — for issues caught quickly, just stop/reverse the CodeDeploy deployment.
2. For a full rollback to EC2: DNS (Route53) can be pointed back at the EC2 instance's ALB/IP, since the EC2 stack was retained rather than destroyed.
3. Because the EC2 app used in-memory state, there's no data reconciliation needed between the two — RDS is the sole source of truth once cut over, and rolling back to EC2 means accepting the EC2 app starts from an empty in-memory store again.
