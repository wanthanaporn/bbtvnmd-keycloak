# Keycloak on AWS ECS - Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Internet Users                                  │
│                         https://auth-kc.bbtvnewmedia.com                    │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │ HTTPS (443) / HTTP (80)
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS Cloud (ap-southeast-1)                         │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Route 53 (Optional DNS)                            │  │
│  │                  auth-kc.bbtvnewmedia.com → ALB                       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                 │                                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    ACM (SSL Certificate)                              │  │
│  │         arn:...dfe58566-53ad-4f93-b900-8fc5aebd17c8                  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                 │                                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                  VPC: bbtvnmd-prod-vpc (10.35.0.0/16)                 │  │
│  │                                                                        │  │
│  │  ┌──────────────────────────────────────────────────────────────┐    │  │
│  │  │              Internet Gateway (igw-0d476c06d802a7c3d)        │    │  │
│  │  └────────────────────────────┬─────────────────────────────────┘    │  │
│  │                               │                                       │  │
│  │  ┌────────────────────────────┴─────────────────────────────────┐    │  │
│  │  │         Public Subnets (Multi-AZ)                            │    │  │
│  │  │  ┌─────────────────────┐    ┌─────────────────────┐         │    │  │
│  │  │  │  AZ-1a: 10.35.1.0/24│    │  AZ-1b: 10.35.2.0/24│         │    │  │
│  │  │  │                     │    │                     │         │    │  │
│  │  │  │  ┌──────────────────────────────────────────┐ │         │    │  │
│  │  │  │  │   Application Load Balancer (ALB)       │ │         │    │  │
│  │  │  │  │   keycloak-alb                          │ │         │    │  │
│  │  │  │  │   SG: sg-07fc46a9d3543aed5              │ │         │    │  │
│  │  │  │  │   Ports: 80 (HTTP), 443 (HTTPS)        │ │         │    │  │
│  │  │  │  └──────────────┬───────────────────────────┘ │         │    │  │
│  │  │  │                 │                             │         │    │  │
│  │  │  │  ┌──────────────┴───────────────────────┐    │         │    │  │
│  │  │  │  │   Target Group: keycloak-tg         │    │         │    │  │
│  │  │  │  │   Port: 8080, Health: /health/ready │    │         │    │  │
│  │  │  │  └──────────────┬───────────────────────┘    │         │    │  │
│  │  │  └─────────────────┼─────────────────────────────┘         │    │  │
│  │  │                    │                                        │    │  │
│  │  │  ┌─────────────────┼─────────────────────┐                 │    │  │
│  │  │  │   NAT Gateway   │                     │                 │    │  │
│  │  │  │   (nat-0f88b221774c44abd)             │                 │    │  │
│  │  │  │   EIP: eipalloc-07d93c7df80b784ca     │                 │    │  │
│  │  │  └─────────────────┬─────────────────────┘                 │    │  │
│  │  └────────────────────┼───────────────────────────────────────┘    │  │
│  │                       │                                             │  │
│  │  ┌────────────────────┴─────────────────────────────────────┐      │  │
│  │  │         Private Subnets (Multi-AZ) - ECS Tasks           │      │  │
│  │  │  ┌─────────────────────┐    ┌─────────────────────┐     │      │  │
│  │  │  │ AZ-1a: 10.35.101.0/24│   │ AZ-1b: 10.35.102.0/24│    │      │  │
│  │  │  │                     │    │                     │     │      │  │
│  │  │  │  ┌──────────────────────────────────────┐     │     │      │  │
│  │  │  │  │   ECS Fargate Tasks                 │     │     │      │  │
│  │  │  │  │   Cluster: keycloak-cluster         │     │     │      │  │
│  │  │  │  │   Service: keycloak-service         │     │     │      │  │
│  │  │  │  │   SG: sg-0bfbc293390b1ad4e          │     │     │      │  │
│  │  │  │  │                                     │     │     │      │  │
│  │  │  │  │   ┌─────────────────────────────┐  │     │     │      │  │
│  │  │  │  │   │  Keycloak Container         │  │     │     │      │  │
│  │  │  │  │   │  Port: 8080                 │  │     │     │      │  │
│  │  │  │  │   │  CPU: 1 vCPU, RAM: 2GB      │  │     │     │      │  │
│  │  │  │  │   │  Image: ECR/keycloak:latest │  │     │     │      │  │
│  │  │  │  │   └─────────────────────────────┘  │     │     │      │  │
│  │  │  │  └──────────────┬───────────────────────┘     │     │      │  │
│  │  │  └─────────────────┼─────────────────────────────┘     │      │  │
│  │  └────────────────────┼───────────────────────────────────┘      │  │
│  │                       │                                           │  │
│  │  ┌────────────────────┴─────────────────────────────────────┐    │  │
│  │  │         Database Subnets (Multi-AZ) - RDS                │    │  │
│  │  │  ┌─────────────────────┐    ┌─────────────────────┐     │    │  │
│  │  │  │ AZ-1a: 10.35.201.0/24│   │ AZ-1b: 10.35.202.0/24│    │    │  │
│  │  │  │                     │    │                     │     │    │  │
│  │  │  │  ┌──────────────────────────────────────┐     │     │    │  │
│  │  │  │  │   RDS PostgreSQL 16.6               │     │     │    │  │
│  │  │  │  │   Instance: keycloak-db             │     │     │    │  │
│  │  │  │  │   Class: db.t4g.micro               │     │     │    │  │
│  │  │  │  │   Storage: 20GB GP3 (encrypted)     │     │     │    │  │
│  │  │  │  │   SG: sg-018d97b1a4a249049          │     │     │    │  │
│  │  │  │  │   Port: 5432                        │     │     │    │  │
│  │  │  │  └─────────────────────────────────────┘     │     │    │  │
│  │  │  └─────────────────────────────────────────────────────┘    │  │
│  │  └──────────────────────────────────────────────────────────┘    │  │
│  │                                                                   │  │
│  │  ┌──────────────────────────────────────────────────────────┐    │  │
│  │  │              VPC Endpoints (Private Link)                │    │  │
│  │  │  • ECR Docker (vpce-0aaf03a6182725c77)                   │    │  │
│  │  │  • ECR API (vpce-0819a8ee65a381627)                      │    │  │
│  │  │  • Secrets Manager (vpce-030bbc24bd46444b2)              │    │  │
│  │  │  • CloudWatch Logs (vpce-01593c0bd076fa5e2)              │    │  │
│  │  │  • S3 Gateway (vpce-04486fbad1bb41bb1)                   │    │  │
│  │  └──────────────────────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    AWS Secrets Manager                            │  │
│  │  • prod/keycloak/db-credentials                                   │  │
│  │  • prod/keycloak/admin-credentials                                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    Amazon ECR                                     │  │
│  │  Repository: bbtvnmd-keycloak                                     │  │
│  │  Image: keycloak:latest                                           │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    CloudWatch Logs                                │  │
│  │  Log Group: /ecs/prod-keycloak-taskdifinition                     │  │
│  │  Retention: 7 days                                                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Network Flow Diagram

### 1. User Request Flow (HTTPS)

```
┌──────────┐
│  User    │
│ Browser  │
└────┬─────┘
     │ 1. HTTPS Request
     │    https://auth-kc.bbtvnewmedia.com
     ▼
┌─────────────────┐
│   Route 53      │ (Optional)
│   DNS Lookup    │
└────┬────────────┘
     │ 2. Returns ALB IP
     ▼
┌─────────────────────────────────────────┐
│   Internet Gateway (IGW)                │
│   igw-0d476c06d802a7c3d                 │
│   Route: 0.0.0.0/0 → IGW                │
└────┬────────────────────────────────────┘
     │ 3. Routes to Public Subnet
     ▼
┌─────────────────────────────────────────┐
│   Application Load Balancer (ALB)      │
│   Public Subnet (10.35.1.0/24)         │
│   Security Group: sg-07fc46a9d3543aed5 │
│   ✓ Inbound: 443 from 0.0.0.0/0        │
│   ✓ SSL Termination (ACM Certificate)  │
└────┬────────────────────────────────────┘
     │ 4. Forward to Target Group
     │    HTTP:8080
     ▼
┌─────────────────────────────────────────┐
│   Target Group: keycloak-tg            │
│   Health Check: /health/ready          │
│   Protocol: HTTP, Port: 8080           │
└────┬────────────────────────────────────┘
     │ 5. Route to ECS Task
     ▼
┌─────────────────────────────────────────┐
│   ECS Fargate Task                     │
│   Private Subnet (10.35.101.0/24)     │
│   Security Group: sg-0bfbc293390b1ad4e │
│   ✓ Inbound: 8080 from ALB SG         │
│                                        │
│   ┌─────────────────────────────────┐ │
│   │  Keycloak Container             │ │
│   │  Listening on: 0.0.0.0:8080     │ │
│   │  KC_PROXY=edge                  │ │
│   │  KC_HTTP_ENABLED=true           │ │
│   └─────────────────────────────────┘ │
└────┬────────────────────────────────────┘
     │ 6. Query Database
     │    PostgreSQL:5432
     ▼
┌─────────────────────────────────────────┐
│   RDS PostgreSQL                       │
│   Database Subnet (10.35.201.0/24)    │
│   Security Group: sg-018d97b1a4a249049 │
│   ✓ Inbound: 5432 from ECS SG         │
│   Database: keycloak                   │
└─────────────────────────────────────────┘
```

### 2. ECS Task Startup Flow

```
┌─────────────────────────────────────────┐
│   ECS Service Starts Task              │
└────┬────────────────────────────────────┘
     │ 1. Pull Container Image
     ▼
┌─────────────────────────────────────────┐
│   VPC Endpoint: ECR Docker             │
│   vpce-0aaf03a6182725c77               │
│   (Private connection to ECR)          │
└────┬────────────────────────────────────┘
     │ 2. Download Image
     ▼
┌─────────────────────────────────────────┐
│   Amazon ECR                           │
│   bbtvnmd-keycloak:latest              │
└────┬────────────────────────────────────┘
     │ 3. Fetch Secrets
     ▼
┌─────────────────────────────────────────┐
│   VPC Endpoint: Secrets Manager        │
│   vpce-030bbc24bd46444b2               │
└────┬────────────────────────────────────┘
     │ 4. Get Credentials
     ▼
┌─────────────────────────────────────────┐
│   AWS Secrets Manager                  │
│   • prod/keycloak/db-credentials       │
│   • prod/keycloak/admin-credentials    │
└────┬────────────────────────────────────┘
     │ 5. Start Container
     ▼
┌─────────────────────────────────────────┐
│   Keycloak Container Running           │
│   • Connect to RDS PostgreSQL          │
│   • Initialize Database Schema         │
│   • Start HTTP Server on :8080         │
└────┬────────────────────────────────────┘
     │ 6. Send Logs
     ▼
┌─────────────────────────────────────────┐
│   VPC Endpoint: CloudWatch Logs        │
│   vpce-01593c0bd076fa5e2               │
└────┬────────────────────────────────────┘
     │ 7. Store Logs
     ▼
┌─────────────────────────────────────────┐
│   CloudWatch Logs                      │
│   /ecs/prod-keycloak-taskdifinition    │
└─────────────────────────────────────────┘
```

### 3. Outbound Internet Access (ECS to Internet)

```
┌─────────────────────────────────────────┐
│   ECS Task (Private Subnet)            │
│   Needs to access AWS Services         │
└────┬────────────────────────────────────┘
     │ 1. Outbound Request
     ▼
┌─────────────────────────────────────────┐
│   Route Table: Private                 │
│   0.0.0.0/0 → NAT Gateway              │
└────┬────────────────────────────────────┘
     │ 2. Route to NAT
     ▼
┌─────────────────────────────────────────┐
│   NAT Gateway                          │
│   Public Subnet (10.35.1.0/24)        │
│   Elastic IP: eipalloc-07d93c7df80b784ca│
└────┬────────────────────────────────────┘
     │ 3. Route to Internet
     ▼
┌─────────────────────────────────────────┐
│   Internet Gateway                     │
│   igw-0d476c06d802a7c3d                │
└────┬────────────────────────────────────┘
     │ 4. Access Internet
     ▼
┌─────────────────────────────────────────┐
│   Internet / AWS Services              │
└─────────────────────────────────────────┘
```

---

## Security Groups Flow

```
┌──────────────────────────────────────────────────────────────┐
│                    Security Group Rules                       │
└──────────────────────────────────────────────────────────────┘

Internet (0.0.0.0/0)
    │
    │ Port 443 (HTTPS)
    │ Port 80 (HTTP)
    ▼
┌─────────────────────────────────┐
│  ALB Security Group             │
│  sg-07fc46a9d3543aed5           │
│  Inbound: 80, 443 from 0.0.0.0/0│
│  Outbound: 8080 to ECS SG       │
└────────────┬────────────────────┘
             │ Port 8080
             ▼
┌─────────────────────────────────┐
│  ECS Security Group             │
│  sg-0bfbc293390b1ad4e           │
│  Inbound: 8080 from ALB SG      │
│  Outbound: 5432 to RDS SG       │
│  Outbound: 443 to 0.0.0.0/0     │
└────────────┬────────────────────┘
             │ Port 5432
             ▼
┌─────────────────────────────────┐
│  RDS Security Group             │
│  sg-018d97b1a4a249049           │
│  Inbound: 5432 from ECS SG      │
│  Outbound: None                 │
└─────────────────────────────────┘
```

---

## Component Details

### Network Components
- **VPC**: 10.35.0.0/16 (bbtvnmd-prod-vpc)
- **Public Subnets**: 10.35.1.0/24, 10.35.2.0/24 (Multi-AZ)
- **Private Subnets**: 10.35.101.0/24, 10.35.102.0/24 (Multi-AZ)
- **Database Subnets**: 10.35.201.0/24, 10.35.202.0/24 (Multi-AZ)
- **Internet Gateway**: igw-0d476c06d802a7c3d
- **NAT Gateway**: nat-0f88b221774c44abd

### Compute Components
- **ECS Cluster**: keycloak-cluster (Fargate)
- **Task Definition**: keycloak-task:4 (1 vCPU, 2GB RAM)
- **Container**: Keycloak 23.0.7 on port 8080

### Load Balancing
- **ALB**: keycloak-alb (Internet-facing)
- **Target Group**: keycloak-tg (HTTP:8080)
- **Listeners**: HTTP:80 (redirect), HTTPS:443

### Database
- **RDS**: PostgreSQL 16.6 (db.t4g.micro)
- **Storage**: 20GB GP3 (encrypted)
- **Backup**: 7 days retention

### Security
- **SSL/TLS**: ACM Certificate
- **Secrets**: AWS Secrets Manager
- **VPC Endpoints**: ECR, Secrets Manager, CloudWatch, S3

---

## Access URLs

- **Production**: https://auth-kc.bbtvnewmedia.com/
- **Admin Console**: https://auth-kc.bbtvnewmedia.com/admin
- **Health Check**: https://auth-kc.bbtvnewmedia.com/health/ready
- **ALB DNS**: http://keycloak-alb-1734647026.ap-southeast-1.elb.amazonaws.com/
