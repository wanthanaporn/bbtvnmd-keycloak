# RDS PostgreSQL - Keycloak Database

## Instance Details

### Basic Information
- **Instance Identifier**: keycloak-db
- **Engine**: PostgreSQL 16.6
- **Instance Class**: db.t4g.micro
  - vCPU: 2 (ARM-based Graviton2)
  - Memory: 1 GB
  - Network Performance: Up to 2085 Mbps
- **Storage**: 20 GB GP3 (General Purpose SSD)
- **Storage Encrypted**: Yes (AES-256)
- **Tags**: Owner=wanthanaporn@ch7.com, Env=prod, Project=bbtvnmd-keycloak

### Network Configuration
- **VPC**: vpc-09f694f971836e5d8 (bbtvnmd-prod-vpc)
- **DB Subnet Group**: keycloak-db-subnet-group
  - Subnet 1: subnet-088b7e782c4ea7916 (10.35.201.0/24, ap-southeast-1a)
  - Subnet 2: subnet-08d26b718f2d3a249 (10.35.202.0/24, ap-southeast-1b)
- **Security Group**: sg-018d97b1a4a249049 (keycloak-rds-sg)
- **Publicly Accessible**: No (Private only)
- **Multi-AZ**: No (Single-AZ for cost optimization)

### Database Configuration
- **Database Name**: keycloak
- **Master Username**: keycloakadmin
- **Port**: 5432 (PostgreSQL default)
- **Parameter Group**: default.postgres16
- **Option Group**: default:postgres-16

### Backup & Maintenance
- **Backup Retention Period**: 7 days
- **Backup Window**: 03:00-04:00 UTC
- **Maintenance Window**: Monday 04:00-05:00 UTC
- **Auto Minor Version Upgrade**: Enabled
- **Deletion Protection**: Enabled

---

## Connection Information

### Endpoint (Available after creation)
```
keycloak-db.<random>.ap-southeast-1.rds.amazonaws.com:5432
```

### JDBC Connection String
```
jdbc:postgresql://<endpoint>:5432/keycloak
```

### Connection from ECS
```bash
Host: <rds-endpoint>
Port: 5432
Database: keycloak
Username: keycloakadmin
Password: <stored-in-secrets-manager>
```

---

## Cost Breakdown (Monthly)

### db.t4g.micro Pricing (ap-southeast-1)
- **Instance Hours**: 730 hours/month
- **Instance Cost**: $0.022/hour × 730 = ~$16.06/month
- **Storage (GP3)**: 20 GB × $0.138/GB = ~$2.76/month
- **Backup Storage**: First 20 GB free, then $0.095/GB
- **Data Transfer**: Within VPC is free

**Total Estimated Cost**: ~$18-20/month

---

## Performance Characteristics

### db.t4g.micro Specs
- **Baseline Performance**: 20% CPU
- **Burst Credits**: Can burst to 100% CPU
- **Network Bandwidth**: Up to 2085 Mbps
- **EBS Bandwidth**: Up to 2085 Mbps

### Expected Performance for Keycloak
- **Concurrent Users**: 100-500 users
- **Connections**: Up to 100 connections (Keycloak default pool)
- **Response Time**: < 100ms for typical queries
- **Suitable For**: Dev, Test, Small Production (< 1000 users)

---

## Monitoring & Maintenance

### CloudWatch Metrics
- CPUUtilization
- DatabaseConnections
- FreeableMemory
- ReadLatency / WriteLatency
- FreeStorageSpace

### Recommended Alarms
```bash
# CPU > 80% for 5 minutes
# Free Memory < 200 MB
# Storage < 2 GB
# Connection Count > 80
```

---

## Scaling Options

### Vertical Scaling (Upgrade Instance)
If performance is insufficient:
1. **db.t4g.small** (2 GB RAM) - ~$32/month
2. **db.t4g.medium** (4 GB RAM) - ~$64/month
3. **db.r6g.large** (16 GB RAM) - ~$200/month

### Storage Scaling
- GP3 can scale up to 64 TB
- Can increase IOPS and throughput independently

### High Availability
- Enable Multi-AZ: +100% cost (~$36-40/month total)
- Automatic failover in case of AZ failure

---

## Security Features

✅ **Encryption at Rest**: AES-256
✅ **Encryption in Transit**: SSL/TLS enforced
✅ **Network Isolation**: Private subnets only
✅ **Security Group**: Restricted to ECS tasks only
✅ **IAM Authentication**: Can be enabled
✅ **Automated Backups**: 7 days retention
✅ **Deletion Protection**: Enabled (prevents accidental deletion)

---

## Backup & Recovery

### Automated Backups
- **Frequency**: Daily during backup window
- **Retention**: 7 days
- **Point-in-Time Recovery**: Yes (within retention period)

### Manual Snapshots
```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier keycloak-db \
  --db-snapshot-identifier keycloak-db-snapshot-$(date +%Y%m%d)
```

### Restore from Snapshot
```bash
# Restore to new instance
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier keycloak-db-restored \
  --db-snapshot-identifier keycloak-db-snapshot-20240101
```

---

## Maintenance Tasks

### Regular Tasks
- [ ] Monitor CloudWatch metrics weekly
- [ ] Review slow query logs monthly
- [ ] Update PostgreSQL minor version quarterly
- [ ] Test backup restoration quarterly
- [ ] Review and optimize queries as needed

### Performance Tuning
```sql
-- Check active connections
SELECT count(*) FROM pg_stat_activity;

-- Check database size
SELECT pg_size_pretty(pg_database_size('keycloak'));

-- Check table sizes
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
```

---

## Status Commands

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier keycloak-db \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address,EngineVersion]' \
  --output table

# Get endpoint
aws rds describe-db-instances \
  --db-instance-identifier keycloak-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# Check recent events
aws rds describe-events \
  --source-identifier keycloak-db \
  --source-type db-instance \
  --duration 60
```

---

## Current Status
🔄 **Creating** (5-10 minutes)

## Next Steps
1. Wait for RDS to become available
2. Get endpoint address
3. Store credentials in AWS Secrets Manager
4. Test connection from ECS
