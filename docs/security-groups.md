# Security Groups - Keycloak on ECS

## Created Security Groups

### 1. ALB Security Group
- **Security Group ID**: sg-07fc46a9d3543aed5
- **Name**: keycloak-alb-sg
- **Description**: Security group for Keycloak ALB
- **VPC**: vpc-09f694f971836e5d8
- **Tags**: Owner=wanthanaporn@ch7.com, Env=prod, Project=bbtvnmd-keycloak

#### Inbound Rules
| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| HTTPS | TCP | 443 | 0.0.0.0/0 | HTTPS from Internet |
| HTTP | TCP | 80 | 0.0.0.0/0 | HTTP from Internet |

#### Outbound Rules
| Type | Protocol | Port | Destination | Description |
|------|----------|------|-------------|-------------|
| Custom TCP | TCP | 8080 | sg-0bfbc293390b1ad4e | To ECS tasks |

---

### 2. ECS Security Group
- **Security Group ID**: sg-0bfbc293390b1ad4e
- **Name**: keycloak-ecs-sg
- **Description**: Security group for Keycloak ECS tasks
- **VPC**: vpc-09f694f971836e5d8
- **Tags**: Owner=wanthanaporn@ch7.com, Env=prod, Project=bbtvnmd-keycloak

#### Inbound Rules
| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| Custom TCP | TCP | 8080 | sg-07fc46a9d3543aed5 | From ALB |

#### Outbound Rules
| Type | Protocol | Port | Destination | Description |
|------|----------|------|-------------|-------------|
| PostgreSQL | TCP | 5432 | sg-018d97b1a4a249049 | To RDS |
| HTTPS | TCP | 443 | 0.0.0.0/0 | To AWS Services |

---

### 3. RDS Security Group
- **Security Group ID**: sg-018d97b1a4a249049
- **Name**: keycloak-rds-sg
- **Description**: Security group for Keycloak RDS PostgreSQL
- **VPC**: vpc-09f694f971836e5d8
- **Tags**: Owner=wanthanaporn@ch7.com, Env=prod, Project=bbtvnmd-keycloak

#### Inbound Rules
| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| PostgreSQL | TCP | 5432 | sg-0bfbc293390b1ad4e | From ECS tasks |

#### Outbound Rules
| Type | Protocol | Port | Destination | Description |
|------|----------|------|-------------|-------------|
| None | - | - | - | No outbound traffic allowed |

---

## Security Flow

```
Internet (0.0.0.0/0)
    │
    │ Port 443/80
    ▼
ALB Security Group (sg-07fc46a9d3543aed5)
    │
    │ Port 8080
    ▼
ECS Security Group (sg-0bfbc293390b1ad4e)
    │
    ├─── Port 5432 ──▶ RDS Security Group (sg-018d97b1a4a249049)
    │
    └─── Port 443 ───▶ Internet (AWS Services: ECR, Secrets Manager)
```

---

## Security Best Practices Applied

✅ **Principle of Least Privilege**
- Each security group only allows necessary traffic
- RDS has no outbound rules (database doesn't need to initiate connections)

✅ **Defense in Depth**
- Multiple layers of security groups
- Traffic flows through controlled paths

✅ **Security Group References**
- Using security group IDs instead of CIDR blocks for internal traffic
- Automatically updates when instances are added/removed

✅ **Separation of Concerns**
- Separate security groups for each tier (ALB, ECS, RDS)
- Easy to manage and audit

---

## Verification Commands

```bash
# Check ALB Security Group
aws ec2 describe-security-groups --group-ids sg-07fc46a9d3543aed5

# Check ECS Security Group
aws ec2 describe-security-groups --group-ids sg-0bfbc293390b1ad4e

# Check RDS Security Group
aws ec2 describe-security-groups --group-ids sg-018d97b1a4a249049
```

---

## Status
✅ All security groups created and configured

## Next Steps
1. Create RDS PostgreSQL instance
2. Create Secrets Manager secrets
3. Create ECR repository
