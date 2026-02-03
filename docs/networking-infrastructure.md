# Networking Infrastructure - bbtvnmd-prod

## Created Resources Summary

### VPC
- **VPC ID**: vpc-09f694f971836e5d8
- **Name**: bbtvnmd-prod-vpc
- **CIDR**: 10.35.0.0/16
- **Region**: ap-southeast-1

---

## Internet Gateway
- **IGW ID**: igw-0d476c06d802a7c3d
- **Name**: bbtvnmd-prod-igw
- **Status**: Attached to vpc-09f694f971836e5d8
- **Tags**: Owner=wanthanaporn@ch7.com, Env=prod, Project=bbtvnmd-keycloak

---

## NAT Gateway
- **NAT Gateway ID**: nat-0f88b221774c44abd
- **Name**: bbtvnmd-prod-nat-gw
- **Elastic IP**: eipalloc-07d93c7df80b784ca
- **Subnet**: subnet-02c461d9bb5134114 (Public Subnet AZ1)
- **Status**: Available
- **Tags**: Owner=wanthanaporn@ch7.com, Env=prod, Project=bbtvnmd-keycloak

---

## Subnets

### Public Subnets (Internet-facing)
| Name | Subnet ID | CIDR | AZ | Usage |
|------|-----------|------|-----|-------|
| bbtvnmd-prod-Public-Subnet (AZ1) | subnet-02c461d9bb5134114 | 10.35.1.0/24 | ap-southeast-1a | ALB |
| bbtvnmd-prod-Public-Subnet (AZ2) | subnet-091f64929b43e46f7 | 10.35.2.0/24 | ap-southeast-1b | ALB |

### Private Subnets (ECS Tasks)
| Name | Subnet ID | CIDR | AZ | Usage |
|------|-----------|------|-----|-------|
| bbtvnmd-prod-Private-Subnet (AZ1) | subnet-0e4abd7d03bffa22a | 10.35.101.0/24 | ap-southeast-1a | ECS Fargate |
| bbtvnmd-prod-Private-Subnet (AZ2) | subnet-0b91c5dc2b062cbd1 | 10.35.102.0/24 | ap-southeast-1b | ECS Fargate |

### Database Subnets (RDS)
| Name | Subnet ID | CIDR | AZ | Usage |
|------|-----------|------|-----|-------|
| bbtvnmd-prod-DB-Subnet (AZ1) | subnet-088b7e782c4ea7916 | 10.35.201.0/24 | ap-southeast-1a | RDS PostgreSQL |
| bbtvnmd-prod-DB-Subnet (AZ2) | subnet-08d26b718f2d3a249 | 10.35.202.0/24 | ap-southeast-1b | RDS PostgreSQL |

---

## Route Tables

### Public Route Table
- **Route Table ID**: rtb-0dd429b10e9e12e11
- **Name**: bbtvnmd-prod-Public-route
- **Routes**:
  - 10.35.0.0/16 → local
  - 0.0.0.0/0 → igw-0d476c06d802a7c3d (Internet Gateway)
- **Associated Subnets**:
  - subnet-02c461d9bb5134114 (Public AZ1)
  - subnet-091f64929b43e46f7 (Public AZ2)

### Private Route Table
- **Route Table ID**: rtb-0a12c394d09f2a49f
- **Name**: bbtvnmd-prod-Private-route
- **Routes**:
  - 10.35.0.0/16 → local
  - 0.0.0.0/0 → nat-0f88b221774c44abd (NAT Gateway)
- **Associated Subnets**:
  - subnet-0e4abd7d03bffa22a (Private AZ1)
  - subnet-0b91c5dc2b062cbd1 (Private AZ2)
  - subnet-088b7e782c4ea7916 (DB AZ1)
  - subnet-08d26b718f2d3a249 (DB AZ2)

---

## Network Flow

```
Internet
    ↓
Internet Gateway (igw-0d476c06d802a7c3d)
    ↓
Public Subnets (10.35.1.0/24, 10.35.2.0/24)
    ↓
Application Load Balancer
    ↓
Private Subnets (10.35.101.0/24, 10.35.102.0/24)
    ↓
ECS Fargate Tasks (Keycloak)
    ↓
Database Subnets (10.35.201.0/24, 10.35.202.0/24)
    ↓
RDS PostgreSQL

Private Subnets → NAT Gateway → Internet (for ECR, Secrets Manager)
```

---

## Status
✅ All networking infrastructure is ready for Keycloak deployment

## Next Steps
1. Create Security Groups
2. Create RDS PostgreSQL
3. Create ECS Infrastructure
