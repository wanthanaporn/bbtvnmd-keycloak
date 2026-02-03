# Keycloak on ECS - Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Internet / Users                            │
└────────────────────────────────┬────────────────────────────────────┘
                                 │ HTTPS (443)
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Route 53 (Optional)                              │
│                  keycloak.yourdomain.com                             │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS Certificate Manager                           │
│                      (SSL/TLS Certificate)                           │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                VPC                                   │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Application Load Balancer (ALB)                  │  │
│  │                    Public Subnets                             │  │
│  │              (AZ-1: 10.0.1.0/24, AZ-2: 10.0.2.0/24)          │  │
│  └─────────────────────────────┬─────────────────────────────────┘  │
│                                │                                     │
│                                │ HTTP (8080)                         │
│                                ▼                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                      ECS Service                              │  │
│  │                    Private Subnets                            │  │
│  │              (AZ-1: 10.0.11.0/24, AZ-2: 10.0.12.0/24)        │  │
│  │  ┌─────────────────────┐    ┌─────────────────────┐          │  │
│  │  │   ECS Task (AZ-1)   │    │   ECS Task (AZ-2)   │          │  │
│  │  │  ┌───────────────┐  │    │  ┌───────────────┐  │          │  │
│  │  │  │   Keycloak    │  │    │  │   Keycloak    │  │          │  │
│  │  │  │   Container   │  │    │  │   Container   │  │          │  │
│  │  │  │   Port: 8080  │  │    │  │   Port: 8080  │  │          │  │
│  │  │  └───────┬───────┘  │    │  └───────┬───────┘  │          │  │
│  │  └──────────┼──────────┘    └──────────┼──────────┘          │  │
│  └─────────────┼──────────────────────────┼─────────────────────┘  │
│                │                           │                         │
│                │ PostgreSQL (5432)         │                         │
│                └───────────┬───────────────┘                         │
│                            ▼                                         │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    RDS PostgreSQL                             │  │
│  │                  Database Subnets                             │  │
│  │              (AZ-1: 10.0.21.0/24, AZ-2: 10.0.22.0/24)        │  │
│  │                                                               │  │
│  │  Database: keycloak                                          │  │
│  │  Multi-AZ: Enabled (Recommended)                             │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              AWS Secrets Manager                              │  │
│  │  - DB Username & Password                                     │  │
│  │  - Keycloak Admin Credentials                                 │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │          Amazon ECR (Elastic Container Registry)              │  │
│  │  Repository: keycloak                                         │  │
│  │  Architecture: x86_64 (amd64)                                 │  │
│  │  Image: <account-id>.dkr.ecr.<region>.amazonaws.com/keycloak │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Network Flow

### 1. User Access Flow (Inbound)
```
User Browser
    │
    │ (1) HTTPS Request (Port 443)
    ▼
Route 53 DNS
    │
    │ (2) Resolve to ALB
    ▼
Application Load Balancer (Public Subnet)
    │
    │ (3) SSL Termination
    │ (4) Health Check: /health/ready
    │ (5) Forward HTTP (Port 8080)
    ▼
ECS Service (Private Subnet)
    │
    │ (6) Target Group routes to healthy tasks
    ▼
Keycloak Container (Port 8080)
    │
    │ (7) Process authentication request
    │ (8) Query database (Port 5432)
    ▼
RDS PostgreSQL (Database Subnet)
    │
    │ (9) Return user/session data
    ▼
Response back through ALB to User
```

### 2. Database Connection Flow
```
Keycloak Container
    │
    │ (1) Retrieve DB credentials
    ▼
AWS Secrets Manager
    │
    │ (2) Return credentials
    ▼
Keycloak Container
    │
    │ (3) Establish connection (Port 5432)
    │     JDBC URL: jdbc:postgresql://rds-endpoint:5432/keycloak
    ▼
RDS PostgreSQL
    │
    │ (4) Authenticate & authorize
    │ (5) Execute queries
    ▼
Return data to Keycloak
```

### 3. Docker Image Build & Push Flow
```
Local Development
    │
    │ (1) Build Docker image (x86_64/amd64)
    │     docker buildx build --platform linux/amd64
    ▼
Docker Image (x86_64)
    │
    │ (2) Tag image
    │     docker tag keycloak:latest <ecr-uri>:latest
    ▼
Authenticate to ECR
    │
    │ (3) aws ecr get-login-password | docker login
    ▼
Push to ECR
    │
    │ (4) docker push <ecr-uri>:latest
    ▼
ECR Repository
    │
    │ Image stored and ready for ECS
    ▼
ECS pulls image when deploying
```

### 4. Container Startup Flow
```
ECS Service
    │
    │ (1) Pull image from ECR
    ▼
ECS Task Definition
    │
    │ (2) Set environment variables
    │     - KC_DB=postgres
    │     - KC_DB_URL_HOST=<rds-endpoint>
    │     - KC_HOSTNAME=<alb-dns-name>
    │     - KC_PROXY=edge
    ▼
Keycloak Container Start
    │
    │ (3) Fetch secrets from Secrets Manager
    │ (4) Initialize database schema
    │ (5) Start Keycloak server
    ▼
Health Check Passes
    │
    │ (6) ALB marks target as healthy
    ▼
Ready to serve traffic
```

## Security Groups Configuration

### ALB Security Group
```
Inbound:
- Port 443 (HTTPS) from 0.0.0.0/0
- Port 80 (HTTP) from 0.0.0.0/0 (redirect to 443)

Outbound:
- Port 8080 to ECS Security Group
```

### ECS Security Group
```
Inbound:
- Port 8080 from ALB Security Group

Outbound:
- Port 5432 to RDS Security Group
- Port 443 to AWS Services (Secrets Manager, ECR)
```

### RDS Security Group
```
Inbound:
- Port 5432 from ECS Security Group

Outbound:
- None required
```

## Key Components

### 0. ECR Configuration
- **Repository Name**: keycloak
- **Image Tag Mutability**: Mutable (or Immutable for production)
- **Scan on Push**: Enabled (security scanning)
- **Architecture**: x86_64 (amd64) - Compatible with Fargate
- **Lifecycle Policy**: Keep last 10 images
- **Encryption**: AES-256 (default)

### 1. VPC Structure
- **CIDR**: 10.0.0.0/16
- **Public Subnets**: 2 AZs for ALB
- **Private Subnets**: 2 AZs for ECS Tasks
- **Database Subnets**: 2 AZs for RDS
- **NAT Gateway**: For ECS tasks to access internet (ECR, Secrets Manager)

### 2. ECS Configuration
- **Launch Type**: Fargate
- **CPU**: 1 vCPU (1024)
- **Memory**: 2 GB (2048)
- **Desired Count**: 2 (Multi-AZ)
- **Health Check**: /health/ready

### 3. RDS Configuration
- **Engine**: PostgreSQL 15.x
- **Instance Class**: db.t3.medium (or higher)
- **Multi-AZ**: Yes (Production)
- **Storage**: 20 GB (Auto-scaling enabled)
- **Backup**: 7 days retention

### 4. ALB Configuration
- **Scheme**: Internet-facing
- **Listeners**: 
  - Port 443 (HTTPS) → Target Group
  - Port 80 (HTTP) → Redirect to 443
- **Target Group**: 
  - Protocol: HTTP
  - Port: 8080
  - Health Check: /health/ready

## Data Flow Summary

1. **Developer → ECR**: Push Docker image (x86_64)
2. **User → ALB**: HTTPS traffic (Port 443)
3. **ALB → ECS**: HTTP traffic (Port 8080) after SSL termination
4. **ECS → ECR**: Pull container images (HTTPS/443)
5. **ECS → RDS**: PostgreSQL connection (Port 5432)
6. **ECS → Secrets Manager**: Retrieve credentials (HTTPS/443)

## High Availability

- **Multi-AZ Deployment**: ECS tasks in 2+ availability zones
- **RDS Multi-AZ**: Automatic failover for database
- **ALB**: Distributes traffic across healthy targets
- **Auto Scaling**: Scale ECS tasks based on CPU/Memory
