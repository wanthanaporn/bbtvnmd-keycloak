# AWS Services Required for Keycloak on ECS

## Account Information
- **AWS Account**: bbtvnmd-prod (461815325316)
- **Region**: ap-southeast-1 (Singapore)
- **Profile**: wanthanaporn_bbtvnmd-prod

### Resource Tags
- **Owner**: wanthanaporn@ch7.com
- **Env**: prod
- **Project**: bbtvnmd-keycloak

---

## 1. Networking Infrastructure

### VPC
- [x] VPC: bbtvnmd-prod-vpc (vpc-09f694f971836e5d8)
  - CIDR: 10.35.0.0/16
  - DNS Resolution: Enabled
  - DNS Hostnames: Enabled
- [x] Internet Gateway: bbtvnmd-prod-igw (igw-0d476c06d802a7c3d)
- [x] NAT Gateway: bbtvnmd-prod-nat-gw (nat-0f88b221774c44abd)
  - Elastic IP: eipalloc-07d93c7df80b784ca

### VPC Endpoints
- [x] Secrets Manager: vpce-030bbc24bd46444b2 (com.amazonaws.ap-southeast-1.secretsmanager)
- [x] ECR Docker: vpce-0aaf03a6182725c77 (com.amazonaws.ap-southeast-1.ecr.dkr)
- [x] ECR API: vpce-0819a8ee65a381627 (com.amazonaws.ap-southeast-1.ecr.api)
- [x] CloudWatch Logs: vpce-01593c0bd076fa5e2 (com.amazonaws.ap-southeast-1.logs)
- [x] S3 Gateway: vpce-04486fbad1bb41bb1 (com.amazonaws.ap-southeast-1.s3)
- Cost: ~$22/month for Interface endpoints

### Subnets (2 AZs)
- [x] Public Subnets (2 subnets)
  - ap-southeast-1a: subnet-02c461d9bb5134114 (10.35.1.0/24) - bbtvnmd-prod-Public-Subnet (AZ1)
  - ap-southeast-1b: subnet-091f64929b43e46f7 (10.35.2.0/24) - bbtvnmd-prod-Public-Subnet (AZ2)
- [x] Private Subnets (2 subnets) - สำหรับ ECS
  - ap-southeast-1a: subnet-0e4abd7d03bffa22a (10.35.101.0/24) - bbtvnmd-prod-Private-Subnet (AZ1)
  - ap-southeast-1b: subnet-0b91c5dc2b062cbd1 (10.35.102.0/24) - bbtvnmd-prod-Private-Subnet (AZ2)
- [x] Database Subnets (2 subnets) - สำหรับ RDS
  - ap-southeast-1a: subnet-088b7e782c4ea7916 (10.35.201.0/24) - bbtvnmd-prod-DB-Subnet (AZ1)
  - ap-southeast-1b: subnet-08d26b718f2d3a249 (10.35.202.0/24) - bbtvnmd-prod-DB-Subnet (AZ2)

### Route Tables
- [x] Public Route Table: bbtvnmd-prod-Public-route (rtb-0dd429b10e9e12e11)
  - Route: 0.0.0.0/0 → igw-0d476c06d802a7c3d
- [x] Private Route Table: bbtvnmd-prod-Private-route (rtb-0a12c394d09f2a49f)
  - Route: 0.0.0.0/0 → nat-0f88b221774c44abd

---

## 2. Security Groups

### ALB Security Group
- [x] Name: keycloak-alb-sg (sg-07fc46a9d3543aed5)
- [x] Inbound Rules:
  - Port 443 (HTTPS) from 0.0.0.0/0
  - Port 80 (HTTP) from 0.0.0.0/0
- [x] Outbound Rules:
  - Port 8080 to ECS Security Group (sg-0bfbc293390b1ad4e)

### ECS Security Group
- [x] Name: keycloak-ecs-sg (sg-0bfbc293390b1ad4e)
- [x] Inbound Rules:
  - Port 8080 from ALB Security Group (sg-07fc46a9d3543aed5)
- [x] Outbound Rules:
  - Port 5432 to RDS Security Group (sg-018d97b1a4a249049)
  - Port 443 to 0.0.0.0/0 (AWS Services: ECR, Secrets Manager)

### RDS Security Group
- [x] Name: keycloak-rds-sg (sg-018d97b1a4a249049)
- [x] Inbound Rules:
  - Port 5432 from ECS Security Group (sg-0bfbc293390b1ad4e)
- [x] Outbound Rules: None

---

## 3. Database (RDS PostgreSQL)

### RDS Instance
- [x] Engine: PostgreSQL 16.6
- [x] Instance Class: db.t4g.micro (ARM-based)
- [x] Instance ID: keycloak-db
- [x] Storage: 20 GB GP3 (encrypted)
- [x] Multi-AZ: No (Single-AZ for cost saving)
- [x] Database Name: keycloak
- [x] Master Username: keycloakadmin
- [x] DB Subnet Group: keycloak-db-subnet-group
  - Subnets: subnet-088b7e782c4ea7916, subnet-08d26b718f2d3a249
- [x] Security Group: sg-018d97b1a4a249049
- [x] Backup Retention: 7 days
- [x] Encryption: Enabled
- [x] Publicly Accessible: No
- [x] Status: Available
- [x] Endpoint: keycloak-db.cqc569pvpohi.ap-southeast-1.rds.amazonaws.com:5432

---

## 4. Secrets Manager

### Secrets to Create
- [x] prod/keycloak/db-credentials
  - ARN: arn:aws:secretsmanager:ap-southeast-1:461815325316:secret:prod/keycloak/db-credentials-Z3x882
  - Description: Keycloak RDS PostgreSQL credentials
  - Keys: username, password, host, port, dbname

- [x] prod/keycloak/admin-credentials
  - ARN: arn:aws:secretsmanager:ap-southeast-1:461815325316:secret:prod/keycloak/admin-credentials-GM6sKc
  - Description: Keycloak admin console credentials
  - Keys: username, password

---

## 5. Container Registry (ECR)

- [x] Repository Name: bbtvnmd-keycloak
- [x] Repository URI: 461815325316.dkr.ecr.ap-southeast-1.amazonaws.com/bbtvnmd-keycloak
- [x] Image Tag Mutability: Mutable
- [x] Scan on Push: Enabled
- [x] Encryption: AES-256
- [x] Lifecycle Policy: Keep last 10 images

---

## 6. ECS Infrastructure

### ECS Cluster
- [x] Cluster Name: keycloak-cluster
- [x] ARN: arn:aws:ecs:ap-southeast-1:461815325316:cluster/keycloak-cluster
- [x] Type: Fargate

### Task Definition
- [x] Family: keycloak-task
- [x] Revision: keycloak-task:4 (latest)
- [x] Launch Type: Fargate
- [x] Network Mode: awsvpc
- [x] CPU: 1024 (1 vCPU)
- [x] Memory: 2048 (2 GB)
- [x] Container:
  - Name: keycloak
  - Image: 461815325316.dkr.ecr.ap-southeast-1.amazonaws.com/bbtvnmd-keycloak:latest
  - Port: 8080
  - Health Check: /health/ready
  - Environment Variables:
    - KC_HTTP_ENABLED=true
    - KC_HOSTNAME_STRICT_HTTPS=false
    - KC_PROXY=edge
    - KC_HOSTNAME=auth-kc.bbtvnewmedia.com

### ECS Service
- [x] Service Name: keycloak-service
- [x] ARN: arn:aws:ecs:ap-southeast-1:461815325316:service/keycloak-cluster/keycloak-service
- [x] Desired Count: 1
- [x] Launch Type: Fargate
- [x] Platform Version: LATEST
- [x] Subnets: Private Subnets (subnet-0e4abd7d03bffa22a, subnet-0b91c5dc2b062cbd1)
- [x] Security Group: sg-0bfbc293390b1ad4e
- [x] Load Balancer: keycloak-tg
- [x] Health Check Grace Period: 300 seconds

---

## 7. Load Balancer (ALB)

### Application Load Balancer
- [x] Name: keycloak-alb
- [x] ARN: arn:aws:elasticloadbalancing:ap-southeast-1:461815325316:loadbalancer/app/keycloak-alb/fae15f31dc7c1452
- [x] DNS: keycloak-alb-1734647026.ap-southeast-1.elb.amazonaws.com
- [x] Scheme: Internet-facing
- [x] IP Address Type: IPv4
- [x] Subnets: subnet-02c461d9bb5134114, subnet-091f64929b43e46f7
- [x] Security Group: sg-07fc46a9d3543aed5

### Target Group
- [x] Name: keycloak-tg
- [x] ARN: arn:aws:elasticloadbalancing:ap-southeast-1:461815325316:targetgroup/keycloak-tg/05bfe1e0d28a3683
- [x] Target Type: IP
- [x] Protocol: HTTP
- [x] Port: 8080
- [x] VPC: vpc-09f694f971836e5d8
- [x] Health Check:
  - Path: /health/ready
  - Interval: 30 seconds
  - Timeout: 5 seconds
  - Healthy Threshold: 2
  - Unhealthy Threshold: 3

### Listeners
- [x] HTTP Listener (Port 80)
  - ARN: arn:aws:elasticloadbalancing:ap-southeast-1:461815325316:listener/app/keycloak-alb/fae15f31dc7c1452/8200aefac40978a4
  - Default Action: Forward to keycloak-tg
- [x] HTTPS Listener (Port 443)
  - ARN: arn:aws:elasticloadbalancing:ap-southeast-1:461815325316:listener/app/keycloak-alb/fae15f31dc7c1452/7427e2ac1886ffb3
  - Default Action: Forward to keycloak-tg

---

## 8. SSL Certificate (ACM)

- [x] Certificate ARN: arn:aws:acm:ap-southeast-1:461815325316:certificate/dfe58566-53ad-4f93-b900-8fc5aebd17c8
- [x] Status: In Use (attached to ALB)

---

## 9. DNS (Route 53) - Optional

- [ ] Hosted Zone: yourdomain.com
- [ ] A Record: keycloak.yourdomain.com → ALB DNS

---

## 10. IAM Roles

### ECS Task Execution Role
- [x] Role Name: keycloak-task-execution-role
- [x] ARN: arn:aws:iam::461815325316:role/keycloak-task-execution-role
- [x] Policies:
  - AmazonECSTaskExecutionRolePolicy
  - keycloak-secrets-manager-policy (arn:aws:iam::461815325316:policy/keycloak-secrets-manager-policy)

### ECS Task Role
- [x] Role Name: keycloak-task-role
- [x] ARN: arn:aws:iam::461815325316:role/keycloak-task-role
- [x] Policies: None (can add as needed)

---

## 11. CloudWatch (Monitoring)

- [x] Log Group: /ecs/prod-keycloak-taskdifinition
- [x] Retention: 7 days
- [ ] Alarms:
  - ECS CPU Utilization > 80%
  - ECS Memory Utilization > 80%
  - ALB Target Unhealthy Count > 0
  - RDS CPU Utilization > 80%

---

## Deployment Order

1. ✅ Login to AWS (bbtvnmd-prod)
2. ✅ Check/Create VPC and Networking
3. ✅ Create Security Groups
4. ✅ Create RDS PostgreSQL
5. ✅ Create Secrets in Secrets Manager
6. ✅ Create ECR Repository
7. ✅ Build and Push Docker Image
8. ✅ Create IAM Roles
9. ✅ Create ALB and Target Group
10. ✅ Create ECS Cluster
11. ✅ Create ECS Task Definition
12. ✅ Create ECS Service
13. ✅ Create VPC Endpoints
14. ✅ Deploy and Verify

---

## Deployment Status

🎉 **Keycloak is RUNNING and ACCESSIBLE!**

### Final Status (2025-02-02 18:30)
- ✅ ECS Service: ACTIVE (1/1 running)
- ✅ Task Definition: keycloak-task:4
- ✅ Target Group: healthy
- ✅ ALB: Configured and working
- ✅ HTTPS: Working with SSL certificate
- ✅ HTTP/2 200: Success!

### 🔴 Root Cause of Initial Problem
**Internet Gateway Route was Blackhole**
- Public Route Table (rtb-0dd429b10e9e12e11) pointed to deleted IGW (igw-08915c7fb7e90b020)
- ALB couldn't receive internet traffic

### ✅ Solution Applied
```bash
aws ec2 replace-route \
  --route-table-id rtb-0dd429b10e9e12e11 \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-0d476c06d802a7c3d
```

### 🌐 Access URLs
- **HTTP**: http://keycloak-alb-1734647026.ap-southeast-1.elb.amazonaws.com/
- **HTTPS**: https://auth-kc.bbtvnewmedia.com/
- **Admin Console**: https://auth-kc.bbtvnewmedia.com/admin
- **Health Check**: https://auth-kc.bbtvnewmedia.com/health/ready

### 🔐 Admin Credentials
- **Username**: admin
- **Password**: Stored in AWS Secrets Manager (prod/keycloak/admin-credentials)

### 📊 Deployment Summary
- **Total Time**: ~8 minutes 53 seconds
- **Infrastructure**: Fully automated with AWS ECS Fargate
- **Database**: PostgreSQL 16.6 on RDS
- **SSL/TLS**: Enabled with ACM certificate
- **High Availability**: Multi-AZ ALB, Single-AZ RDS (cost optimized)

---

## Estimated Costs (Monthly)

- **RDS db.t4g.micro (Single-AZ)**: ~$16-20
- **ECS Fargate (1 task, 1vCPU, 2GB)**: ~$30
- **ALB**: ~$20
- **NAT Gateway**: ~$35
- **VPC Endpoints (4 Interface)**: ~$22
- **Data Transfer**: Variable
- **Total**: ~$123-127/month (With VPC Endpoints)

---

## Notes

- Use existing VPC if available to save costs
- Consider using Single-AZ RDS for dev/test environments
- Enable CloudWatch Container Insights for better monitoring
- Set up auto-scaling for ECS service based on CPU/Memory
- Regular backup and disaster recovery plan
