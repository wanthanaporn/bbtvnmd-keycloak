# Keycloak Network Flow Documentation

## Overview

This document describes the complete network flow for Keycloak deployment on AWS ECS Fargate, including all traffic paths, security controls, and component interactions.

---

## 1. User Access Flow (Production Traffic)

### HTTPS Request Flow

```
Step 1: User initiates HTTPS request
┌──────────────────────────────────────────────────────────────┐
│ User Browser                                                  │
│ URL: https://auth-kc.bbtvnewmedia.com                        │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ DNS Resolution (Optional via Route 53)
                         │ Returns: ALB IP addresses
                         │
Step 2: Request reaches AWS
┌────────────────────────▼─────────────────────────────────────┐
│ Internet Gateway (igw-0d476c06d802a7c3d)                     │
│ • Attached to VPC: bbtvnmd-prod-vpc                          │
│ • Route: 0.0.0.0/0 → IGW (in Public Route Table)            │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Routes to Public Subnet
                         │
Step 3: ALB receives request
┌────────────────────────▼─────────────────────────────────────┐
│ Application Load Balancer (keycloak-alb)                     │
│ • Location: Public Subnets (Multi-AZ)                        │
│   - AZ-1a: 10.35.1.0/24                                      │
│   - AZ-1b: 10.35.2.0/24                                      │
│ • Security Group: sg-07fc46a9d3543aed5                       │
│   ✓ Inbound: Port 443 from 0.0.0.0/0                         │
│   ✓ Inbound: Port 80 from 0.0.0.0/0                          │
│ • SSL Termination: ACM Certificate                           │
│   (arn:...dfe58566-53ad-4f93-b900-8fc5aebd17c8)             │
│                                                              │
│ Listeners:                                                   │
│ • Port 443 (HTTPS) → Forward to Target Group                │
│ • Port 80 (HTTP) → Redirect to HTTPS                        │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Decrypts HTTPS → HTTP:8080
                         │
Step 4: Target Group routing
┌────────────────────────▼─────────────────────────────────────┐
│ Target Group (keycloak-tg)                                   │
│ • Protocol: HTTP                                             │
│ • Port: 8080                                                 │
│ • Target Type: IP (Fargate tasks)                           │
│ • Health Check:                                              │
│   - Path: /health/ready                                      │
│   - Interval: 30s                                            │
│   - Timeout: 5s                                              │
│   - Healthy threshold: 2                                     │
│   - Unhealthy threshold: 3                                   │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Routes to healthy ECS task
                         │
Step 5: ECS Task processes request
┌────────────────────────▼─────────────────────────────────────┐
│ ECS Fargate Task (keycloak-service)                         │
│ • Location: Private Subnets                                  │
│   - AZ-1a: 10.35.101.0/24                                    │
│   - AZ-1b: 10.35.102.0/24                                    │
│ • Security Group: sg-0bfbc293390b1ad4e                       │
│   ✓ Inbound: Port 8080 from ALB SG only                      │
│   ✓ Outbound: Port 5432 to RDS SG                           │
│   ✓ Outbound: Port 443 to 0.0.0.0/0 (AWS Services)          │
│                                                              │
│ ┌──────────────────────────────────────────────────────┐    │
│ │ Keycloak Container                                   │    │
│ │ • Image: ECR/bbtvnmd-keycloak:latest                 │    │
│ │ • Port: 8080                                         │    │
│ │ • CPU: 1 vCPU, Memory: 2GB                           │    │
│ │ • Environment:                                       │    │
│ │   - KC_HTTP_ENABLED=true                             │    │
│ │   - KC_PROXY=edge                                    │    │
│ │   - KC_HOSTNAME=auth-kc.bbtvnewmedia.com            │    │
│ │   - KC_HOSTNAME_STRICT_HTTPS=false                   │    │
│ └──────────────────────────────────────────────────────┘    │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Database queries (if needed)
                         │
Step 6: Database access
┌────────────────────────▼─────────────────────────────────────┐
│ RDS PostgreSQL (keycloak-db)                                │
│ • Location: Database Subnets                                 │
│   - AZ-1a: 10.35.201.0/24                                    │
│   - AZ-1b: 10.35.202.0/24                                    │
│ • Security Group: sg-018d97b1a4a249049                       │
│   ✓ Inbound: Port 5432 from ECS SG only                      │
│   ✓ Outbound: None                                           │
│ • Engine: PostgreSQL 16.6                                    │
│ • Instance: db.t4g.micro                                     │
│ • Storage: 20GB GP3 (encrypted)                              │
│ • Database: keycloak                                         │
└──────────────────────────────────────────────────────────────┘

Response flows back through the same path:
ECS Task → Target Group → ALB → Internet Gateway → User
```

---

## 2. ECS Task Initialization Flow

### Container Startup Sequence

```
Step 1: ECS Service triggers task start
┌──────────────────────────────────────────────────────────────┐
│ ECS Service (keycloak-service)                               │
│ • Desired Count: 1                                           │
│ • Launch Type: Fargate                                       │
│ • Task Definition: keycloak-task:4                           │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Request to pull container image
                         │
Step 2: Pull image from ECR
┌────────────────────────▼─────────────────────────────────────┐
│ VPC Endpoint: ECR Docker                                     │
│ • Endpoint ID: vpce-0aaf03a6182725c77                        │
│ • Service: com.amazonaws.ap-southeast-1.ecr.dkr              │
│ • Type: Interface (PrivateLink)                              │
│ • Location: Private Subnets                                  │
│ • Security Group: Allows HTTPS from ECS SG                   │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Private connection (no internet)
                         │
┌────────────────────────▼─────────────────────────────────────┐
│ Amazon ECR                                                   │
│ • Repository: bbtvnmd-keycloak                               │
│ • Image: latest                                              │
│ • URI: 461815325316.dkr.ecr.ap-southeast-1.amazonaws.com    │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Image downloaded
                         │
Step 3: Fetch secrets
┌────────────────────────▼─────────────────────────────────────┐
│ VPC Endpoint: Secrets Manager                                │
│ • Endpoint ID: vpce-030bbc24bd46444b2                        │
│ • Service: com.amazonaws.ap-southeast-1.secretsmanager       │
│ • Type: Interface (PrivateLink)                              │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Private connection
                         │
┌────────────────────────▼─────────────────────────────────────┐
│ AWS Secrets Manager                                          │
│ Secrets retrieved:                                           │
│ • prod/keycloak/db-credentials                               │
│   - username: keycloakadmin                                  │
│   - password: [encrypted]                                    │
│   - host: keycloak-db.cqc569pvpohi...                        │
│   - port: 5432                                               │
│   - dbname: keycloak                                         │
│                                                              │
│ • prod/keycloak/admin-credentials                            │
│   - username: admin                                          │
│   - password: [encrypted]                                    │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Secrets injected as env vars
                         │
Step 4: Container starts
┌────────────────────────▼─────────────────────────────────────┐
│ Keycloak Container Initialization                            │
│ 1. Load configuration                                        │
│ 2. Connect to PostgreSQL database                            │
│ 3. Run database migrations (if needed)                       │
│ 4. Initialize Keycloak services                              │
│ 5. Start HTTP server on port 8080                            │
│ 6. Register with Target Group                                │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Send logs
                         │
Step 5: Logging
┌────────────────────────▼─────────────────────────────────────┐
│ VPC Endpoint: CloudWatch Logs                                │
│ • Endpoint ID: vpce-01593c0bd076fa5e2                        │
│ • Service: com.amazonaws.ap-southeast-1.logs                 │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Stream logs
                         │
┌────────────────────────▼─────────────────────────────────────┐
│ CloudWatch Logs                                              │
│ • Log Group: /ecs/prod-keycloak-taskdifinition               │
│ • Retention: 7 days                                          │
│ • Logs: Container stdout/stderr                              │
└──────────────────────────────────────────────────────────────┘

Step 6: Health check
┌──────────────────────────────────────────────────────────────┐
│ ALB Health Check                                             │
│ • Target: ECS Task IP:8080                                   │
│ • Path: /health/ready                                        │
│ • Expected: HTTP 200                                         │
│ • After 2 successful checks → Task marked "healthy"          │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Outbound Internet Access Flow

### ECS Task to Internet (via NAT Gateway)

```
Scenario: ECS task needs to access external services
(e.g., software updates, external APIs)

Step 1: Task initiates outbound request
┌──────────────────────────────────────────────────────────────┐
│ ECS Task (Private Subnet)                                    │
│ • Source IP: 10.35.101.x                                     │
│ • Destination: Internet (e.g., api.example.com)              │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Lookup route table
                         │
Step 2: Route table lookup
┌────────────────────────▼─────────────────────────────────────┐
│ Private Route Table (rtb-0a12c394d09f2a49f)                  │
│ Routes:                                                      │
│ • 10.35.0.0/16 → local (VPC internal)                        │
│ • 0.0.0.0/0 → nat-0f88b221774c44abd                          │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Route to NAT Gateway
                         │
Step 3: NAT Gateway
┌────────────────────────▼─────────────────────────────────────┐
│ NAT Gateway (nat-0f88b221774c44abd)                          │
│ • Location: Public Subnet (10.35.1.0/24)                     │
│ • Elastic IP: eipalloc-07d93c7df80b784ca                     │
│ • Function: Network Address Translation                      │
│   - Translates private IP → public IP                        │
│   - Maintains connection state                               │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Forward to Internet Gateway
                         │
Step 4: Internet Gateway
┌────────────────────────▼─────────────────────────────────────┐
│ Internet Gateway (igw-0d476c06d802a7c3d)                     │
│ • Routes traffic to/from internet                            │
│ • Stateless (no connection tracking)                         │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ To internet
                         │
┌────────────────────────▼─────────────────────────────────────┐
│ Internet / External Services                                 │
└──────────────────────────────────────────────────────────────┘

Response path:
Internet → IGW → NAT Gateway → Private Subnet → ECS Task
```

---

## 4. VPC Endpoints Flow (AWS Services)

### Private Access to AWS Services

```
Scenario: ECS task accesses AWS services without internet

┌──────────────────────────────────────────────────────────────┐
│ ECS Task needs to access AWS services:                       │
│ • ECR (pull images)                                          │
│ • Secrets Manager (get secrets)                              │
│ • CloudWatch Logs (send logs)                                │
│ • S3 (if needed)                                             │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ DNS resolution
                         │
┌────────────────────────▼─────────────────────────────────────┐
│ VPC DNS Resolution                                           │
│ • ecr.dkr.ap-southeast-1.amazonaws.com                       │
│   → Resolves to VPC Endpoint IP (10.35.x.x)                  │
│ • secretsmanager.ap-southeast-1.amazonaws.com                │
│   → Resolves to VPC Endpoint IP (10.35.x.x)                  │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Traffic stays in VPC
                         │
┌────────────────────────▼─────────────────────────────────────┐
│ VPC Endpoints (Interface Type - PrivateLink)                 │
│                                                              │
│ ┌──────────────────────────────────────────────────────┐    │
│ │ ECR Docker Endpoint (vpce-0aaf03a6182725c77)         │    │
│ │ • Service: com.amazonaws.ap-southeast-1.ecr.dkr      │    │
│ │ • ENI in Private Subnets                             │    │
│ └──────────────────────────────────────────────────────┘    │
│                                                              │
│ ┌──────────────────────────────────────────────────────┐    │
│ │ ECR API Endpoint (vpce-0819a8ee65a381627)            │    │
│ │ • Service: com.amazonaws.ap-southeast-1.ecr.api      │    │
│ └──────────────────────────────────────────────────────┘    │
│                                                              │
│ ┌──────────────────────────────────────────────────────┐    │
│ │ Secrets Manager (vpce-030bbc24bd46444b2)             │    │
│ │ • Service: com.amazonaws...secretsmanager            │    │
│ └──────────────────────────────────────────────────────┘    │
│                                                              │
│ ┌──────────────────────────────────────────────────────┐    │
│ │ CloudWatch Logs (vpce-01593c0bd076fa5e2)             │    │
│ │ • Service: com.amazonaws.ap-southeast-1.logs         │    │
│ └──────────────────────────────────────────────────────┘    │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ AWS PrivateLink
                         │ (Private connection)
                         │
┌────────────────────────▼─────────────────────────────────────┐
│ AWS Services                                                 │
│ • Amazon ECR                                                 │
│ • AWS Secrets Manager                                        │
│ • Amazon CloudWatch                                          │
└──────────────────────────────────────────────────────────────┘

Benefits:
✓ No internet gateway needed for AWS services
✓ Traffic stays within AWS network
✓ Lower latency
✓ Enhanced security
✓ Reduced data transfer costs
```

---

## 5. Security Group Chain

### Traffic Flow Through Security Groups

```
┌──────────────────────────────────────────────────────────────┐
│                    Security Group Flow                        │
└──────────────────────────────────────────────────────────────┘

Internet (0.0.0.0/0)
    │
    │ Port 443 (HTTPS) ✓
    │ Port 80 (HTTP) ✓
    ▼
┌─────────────────────────────────────────────────────────────┐
│ ALB Security Group (sg-07fc46a9d3543aed5)                   │
│                                                             │
│ Inbound Rules:                                              │
│ ✓ Type: HTTPS, Port: 443, Source: 0.0.0.0/0                │
│ ✓ Type: HTTP, Port: 80, Source: 0.0.0.0/0                  │
│ ✓ Type: ICMP, Protocol: All, Source: 0.0.0.0/0             │
│                                                             │
│ Outbound Rules:                                             │
│ ✓ Type: Custom TCP, Port: 8080, Dest: sg-0bfbc293390b1ad4e │
│ ✓ Type: All traffic, Dest: 0.0.0.0/0                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Port 8080 ✓
                         │ (Only from ALB SG)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ ECS Security Group (sg-0bfbc293390b1ad4e)                   │
│                                                             │
│ Inbound Rules:                                              │
│ ✓ Type: Custom TCP, Port: 8080, Source: sg-07fc46a9d3543aed5│
│   (Only accepts traffic from ALB)                           │
│                                                             │
│ Outbound Rules:                                             │
│ ✓ Type: PostgreSQL, Port: 5432, Dest: sg-018d97b1a4a249049 │
│ ✓ Type: HTTPS, Port: 443, Dest: 0.0.0.0/0                  │
│   (For AWS services via VPC endpoints)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Port 5432 ✓
                         │ (Only from ECS SG)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ RDS Security Group (sg-018d97b1a4a249049)                   │
│                                                             │
│ Inbound Rules:                                              │
│ ✓ Type: PostgreSQL, Port: 5432, Source: sg-0bfbc293390b1ad4e│
│   (Only accepts traffic from ECS tasks)                     │
│                                                             │
│ Outbound Rules:                                             │
│ ✗ None (Database doesn't initiate outbound connections)     │
└─────────────────────────────────────────────────────────────┘

Security Principles:
✓ Least privilege access
✓ Defense in depth (multiple layers)
✓ Source-based restrictions (SG references)
✓ No direct internet access to ECS or RDS
```

---

## 6. Complete Request-Response Cycle

### End-to-End Flow with Timing

```
Time    Component                Action
────────────────────────────────────────────────────────────────
0ms     User Browser            Initiates HTTPS request
                                https://auth-kc.bbtvnewmedia.com

10ms    DNS (Route 53)          Resolves to ALB IP addresses
                                Returns: 54.151.234.114, 13.250.194.198

20ms    Internet Gateway        Routes request to VPC
                                Destination: Public Subnet

25ms    ALB                     Receives HTTPS request
                                - SSL termination (decrypt)
                                - Health check validation
                                - Select healthy target

30ms    Target Group            Routes to ECS task
                                Protocol: HTTP, Port: 8080

35ms    ECS Task                Receives HTTP request
                                Container: Keycloak

40ms    Keycloak                Processes request
                                - Session validation
                                - Database query (if needed)

45ms    RDS PostgreSQL          Query execution
                                - Fetch user data
                                - Return results

50ms    Keycloak                Generates response
                                - HTML/JSON rendering

55ms    ECS Task                Sends response back

60ms    Target Group            Forwards response

65ms    ALB                     Encrypts response (TLS)
                                Adds headers

70ms    Internet Gateway        Routes to internet

80ms    User Browser            Receives response
                                Renders page

Total: ~80ms (typical response time)
```

---

## Network Optimization

### Current Configuration Benefits

1. **Multi-AZ Deployment**
   - ALB spans 2 availability zones
   - Automatic failover
   - High availability

2. **VPC Endpoints**
   - Reduced NAT Gateway costs
   - Lower latency to AWS services
   - Enhanced security

3. **Private Subnets**
   - ECS tasks not directly accessible
   - RDS completely isolated
   - Defense in depth

4. **Security Groups**
   - Stateful firewall
   - Source-based rules
   - Minimal attack surface

### Cost Optimization

- **NAT Gateway**: Required for outbound internet
  - Cost: ~$35/month
  - Alternative: VPC Endpoints (already implemented)

- **VPC Endpoints**: ~$22/month
  - Saves NAT Gateway data transfer costs
  - Recommended for production

---

## Troubleshooting Network Issues

### Common Issues and Solutions

1. **Cannot access Keycloak from internet**
   - Check: Internet Gateway route (0.0.0.0/0 → IGW)
   - Check: ALB Security Group (ports 80, 443 open)
   - Check: ALB in public subnets

2. **ECS tasks unhealthy**
   - Check: ECS Security Group (port 8080 from ALB SG)
   - Check: Target Group health check path
   - Check: Container listening on 0.0.0.0:8080

3. **Cannot connect to RDS**
   - Check: RDS Security Group (port 5432 from ECS SG)
   - Check: RDS in database subnets
   - Check: Database credentials in Secrets Manager

4. **Cannot pull ECR images**
   - Check: VPC Endpoint for ECR
   - Check: NAT Gateway if no VPC endpoint
   - Check: ECS task execution role permissions

---

## Monitoring and Logging

### Network Flow Monitoring

1. **VPC Flow Logs** (Optional)
   - Capture IP traffic
   - Analyze network patterns
   - Troubleshoot connectivity

2. **ALB Access Logs** (Optional)
   - Request/response details
   - Client IP addresses
   - Response times

3. **CloudWatch Metrics**
   - ALB request count
   - Target response time
   - Unhealthy target count
   - ECS CPU/Memory utilization

---

## Summary

The Keycloak deployment uses a secure, highly available architecture:

- ✅ Public-facing ALB with SSL termination
- ✅ Private ECS tasks (no direct internet access)
- ✅ Isolated RDS database
- ✅ VPC Endpoints for AWS services
- ✅ Multi-layer security (Security Groups, Network ACLs)
- ✅ Multi-AZ for high availability
- ✅ Comprehensive logging and monitoring

**Access URL**: https://auth-kc.bbtvnewmedia.com/
