# EC2 Legacy Application

This is a **legacy Flask application** running on a single EC2 instance behind Nginx. It represents a typical "before" state of an application that needs to be migrated to a modern containerized platform.

## Architecture

```
Internet → EC2 Instance (Public Subnet)
              ├── Nginx (Port 80)
              │     ├── /            → Static frontend (SPA console)
              │     ├── /api/*       → Flask App (proxy)
              │     └── /health      → Flask App (proxy)
              └── Flask App (Gunicorn, Port 5000)
```

### Components

- **Static Frontend**: A dependency-free single-page console (HTML/CSS/JS) served by Nginx
- **Flask Application**: Python/Flask API with REST endpoints
- **Gunicorn**: WSGI HTTP Server running the Flask app
- **Nginx**: Reverse proxy serving HTTP on port 80 and the static frontend
- **Systemd**: Service manager for the Flask application
- **Terraform**: Infrastructure as Code for provisioning

## Application Features

The Flask API provides the following endpoints:

- `GET /health` - Health check endpoint
- `GET /api/v1/products` - List all products
- `GET /api/v1/products/{id}` - Get specific product
- `POST /api/v1/orders` - Create a new order
- `GET /api/v1/orders` - List all orders
- `GET /api/v1/stats` - Application statistics

## Frontend

A lightweight web console lives in [`frontend/`](frontend/). It is plain HTML,
CSS, and vanilla JavaScript — no build step and no dependencies — so it runs
directly on the legacy EC2 instance.

It provides:

- A **live health badge** that polls `GET /health`
- A **stats dashboard** (products, orders, revenue) from `GET /api/v1/stats`
- A **product catalog** from `GET /api/v1/products` with an inline "Order" action
- An **order to place** flow that calls `POST /api/v1/orders`
- An **orders table** from `GET /api/v1/orders`

### How it connects to the API

Nginx serves the frontend at `/` and proxies `/api/` and `/health` to Flask on
the same host and port. Because everything is served from the same origin, the
frontend calls the API with relative paths (e.g. `fetch('/api/v1/products')`)
and there are **no CORS concerns**.

### Running the frontend locally against a remote API

You can open `frontend/index.html` in a browser during development and point it
at a deployed instance:

1. Click **Change** in the footer (or edit `frontend/config.js`).
2. Set the API base to `http://<ec2-ip-or-domain>` and refresh.

> Note: pointing a locally-opened page at a remote API is cross-origin. The
> legacy Flask app does not send CORS headers, so the recommended path is the
> same-origin deployment via Nginx (which is how it runs on EC2).

### Deployment

`scripts/setup.sh` copies `frontend/` to `/var/www/flask-frontend`, which Nginx
serves as its web root. No extra steps are required beyond the standard deploy.

## Prerequisites

- **AWS Account** with appropriate permissions
- **Terraform** >= 1.5.0
- **AWS CLI** configured (for manual testing)
- **SSH Key Pair** created in AWS (optional, for SSH access)

## Deployment

### 1. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review Plan

```bash
terraform plan
```

### 4. Deploy Infrastructure

```bash
terraform apply
```

This will create:
- VPC with public and private subnets
- Internet Gateway and Route Tables
- Security Groups
- EC2 instance with Elastic IP
- S3 bucket for application files
- IAM roles and policies
- (Optional) Route53 DNS record

### 5. Wait for Application Setup

The EC2 instance will automatically:
1. Download application files from S3
2. Install system dependencies
3. Set up Python virtual environment
4. Configure Nginx
5. Start the Flask application via systemd

Check the instance status:

```bash
# Get instance IP
terraform output ec2_instance_public_ip

# SSH into instance (if key pair configured)
ssh -i ~/.ssh/your-key.pem ubuntu@<instance-ip>

# Check application logs
sudo journalctl -u flask-app -f
sudo tail -f /var/log/nginx/flask-access.log
```

### 6. Test the Application

```bash
# Get application URL
APP_URL=$(terraform output -raw application_url)
echo $APP_URL

# Health check
curl $APP_URL/health

# List products
curl $APP_URL/api/v1/products

# Create an order
curl -X POST $APP_URL/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "quantity": 2}'
```

## Application Access

The application will be accessible via:
- **Public IP**: Use `terraform output ec2_instance_public_ip`
- **Domain Name**: If Route53 is configured, use `terraform output route53_record`

Default endpoint: `http://<ip-or-domain>/health`

## Logs

Application logs are located on the EC2 instance:

- **Application logs**: `/var/log/flask-app/`
  - `access.log` - Gunicorn access logs
  - `error.log` - Gunicorn error logs
- **Systemd logs**: `sudo journalctl -u flask-app -f`
- **Nginx logs**: `/var/log/nginx/`
  - `flask-access.log` - Nginx access logs
  - `flask-error.log` - Nginx error logs

## Service Management

```bash
# Check service status
sudo systemctl status flask-app
sudo systemctl status nginx

# Restart application
sudo systemctl restart flask-app

# View logs
sudo journalctl -u flask-app -f
```

## Troubleshooting

### Application not responding

1. Check if services are running:
   ```bash
   sudo systemctl status flask-app
   sudo systemctl status nginx
   ```

2. Check application logs:
   ```bash
   sudo journalctl -u flask-app -n 50
   tail -f /var/log/flask-app/error.log
   ```

3. Test Flask app directly:
   ```bash
   curl http://localhost:5000/health
   ```

4. Check Nginx configuration:
   ```bash
   sudo nginx -t
   sudo tail -f /var/log/nginx/flask-error.log
   ```

### Health check fails

1. Ensure Gunicorn is bound to `127.0.0.1:5000`:
   ```bash
   sudo netstat -tlnp | grep 5000
   ```

2. Test health endpoint directly:
   ```bash
   curl http://127.0.0.1:5000/health
   ```

### Permission issues

Ensure correct ownership:

```bash
sudo chown -R ubuntu:ubuntu /opt/flask-app
sudo chown -R ubuntu:ubuntu /var/log/flask-app
```

## Legacy Limitations

This EC2 setup (kept here for reference / rollback) has several limitations
that made it unsuitable for production long-term:

- ❌ **No autoscaling**: Single instance, no horizontal scaling
- ❌ **No high availability**: Single point of failure
- ❌ **Manual deployments**: No CI/CD pipeline
- ❌ **Inconsistent logging**: Logs scattered across instance
- ❌ **No observability**: Limited metrics and monitoring
- ❌ **Manual configuration**: No infrastructure as code for app config
- ❌ **No containerization**: Difficult to replicate environments
- ❌ **Single AZ**: Not resilient to AZ failures
- ❌ **No blue/green deployments**: Downtime during updates
- ❌ **Security**: App runs in public subnet with public IP

## Current State: Migrated to ECS

This application has since been migrated to Amazon ECS (Fargate). The
Terraform in `terraform/ecs-app/` is the source of truth for the running
infrastructure; the EC2 stack in `terraform/ec2-app/` is retained only as a
reference/rollback path. See [`MIGRATION.md`](MIGRATION.md) for the full
migration record, cost breakdown, and trade-offs of the design decisions made.

- ✅ **Amazon ECS (Fargate)**: Containerized, managed service
- ✅ **Application Load Balancer**: High availability, health checks
- ✅ **Private subnets**: Enhanced security
- ✅ **Auto-scaling**: Horizontal scaling based on demand
- ✅ **CI/CD pipeline**: GitHub Actions with OIDC, Trivy scanning, signed images
- ✅ **CloudWatch**: Centralized logging and metrics
- ✅ **Multi-AZ**: High availability
- ✅ **Zero-downtime deployments**: Blue/green via CodeDeploy

## Cleanup

To destroy the legacy EC2 stack:

```bash
cd terraform/ec2-app
terraform destroy
```

To destroy the ECS stack:

```bash
cd terraform/ecs-app
terraform destroy
```

⚠️ **Warning**: This deletes the matching resources, including any data in RDS
(the legacy stack has no persistent data store).

## License

MIT — see [`LICENSE`](LICENSE).
