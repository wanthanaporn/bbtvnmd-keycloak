# Docker Build & Push Instructions

## Prerequisites
- Docker installed with buildx support
- AWS CLI configured with appropriate credentials
- Logged into AWS account (bbtvnmd-prod)

## Build and Push to ECR

### Quick Start
```bash
# Build and push with default tag (latest)
./scripts/build-and-push.sh

# Build and push with specific tag
./scripts/build-and-push.sh v1.0.0
```

### Manual Steps

1. **Set AWS Profile**
```bash
export AWS_PROFILE=wanthanaporn_bbtvnmd-prod
```

2. **Get Account ID and Region**
```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ap-southeast-1"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/keycloak"
```

3. **Create ECR Repository (if not exists)**
```bash
aws ecr create-repository \
    --repository-name keycloak \
    --region ap-southeast-1 \
    --image-scanning-configuration scanOnPush=true
```

4. **Authenticate Docker to ECR**
```bash
aws ecr get-login-password --region ap-southeast-1 | \
    docker login --username AWS --password-stdin ${ECR_URI}
```

5. **Build Image for x86_64 (Fargate compatible)**
```bash
docker buildx build --platform linux/amd64 -t keycloak:latest .
```

6. **Tag and Push**
```bash
docker tag keycloak:latest ${ECR_URI}:latest
docker push ${ECR_URI}:latest
```

## Dockerfile Details

- **Base Image**: quay.io/keycloak/keycloak:23.0
- **Platform**: linux/amd64 (x86_64)
- **Database**: PostgreSQL
- **Features**: Health checks, Metrics, Edge proxy mode
- **Port**: 8080

## Environment Variables (Set in ECS Task Definition)

Required:
- `KC_DB_URL_HOST`: RDS endpoint
- `KC_DB_URL_DATABASE`: Database name (keycloak)
- `KC_DB_USERNAME`: Database username (from Secrets Manager)
- `KC_DB_PASSWORD`: Database password (from Secrets Manager)
- `KC_HOSTNAME`: ALB DNS name
- `KEYCLOAK_ADMIN`: Admin username (from Secrets Manager)
- `KEYCLOAK_ADMIN_PASSWORD`: Admin password (from Secrets Manager)

## Verify Image

```bash
# List images in ECR
aws ecr list-images --repository-name keycloak --region ap-southeast-1

# Describe image
aws ecr describe-images --repository-name keycloak --region ap-southeast-1
```

## Image URI Format

```
461815325316.dkr.ecr.ap-southeast-1.amazonaws.com/keycloak:latest
```
