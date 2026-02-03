# Keycloak Troubleshooting Guide

## Issue: Cannot access https://auth-kc.bbtvnewmedia.com

### Status Check (2025-02-02)

✅ **Infrastructure Status:**
- ECS Service: ACTIVE (1/1 running)
- Task Definition: keycloak-task:4
- Target Group: healthy (10.35.101.144)
- Keycloak Container: Running on port 8080
- ALB Security Group: Port 80, 443 open to 0.0.0.0/0
- HTTPS Listener: Configured with SSL certificate

❌ **Connection Issue:**
- Cannot connect to https://auth-kc.bbtvnewmedia.com (timeout)
- Cannot connect to http://keycloak-alb-1734647026.ap-southeast-1.elb.amazonaws.com (timeout)
- DNS resolves correctly: 54.151.234.114, 13.250.194.198

### Root Cause Analysis

The issue is **NOT** with:
- Keycloak configuration ✅
- ECS/Fargate setup ✅
- Target Group health ✅
- Security Groups ✅
- SSL Certificate ✅

The issue **IS** with:
- **Network connectivity from your current location to AWS ALB**
- Possible causes:
  1. Corporate firewall blocking outbound HTTPS to AWS
  2. VPN or proxy configuration
  3. Network ACLs on VPC subnets
  4. Your ISP blocking the connection

### Verification Steps

#### 1. Test from Different Network
Try accessing from:
- Mobile hotspot (different network)
- Different WiFi network
- AWS CloudShell
- EC2 instance in same VPC

#### 2. Test from AWS CloudShell
```bash
# Login to AWS Console → CloudShell
curl -I http://keycloak-alb-1734647026.ap-southeast-1.elb.amazonaws.com/
curl -I https://auth-kc.bbtvnewmedia.com/
```

#### 3. Check Network ACLs
```bash
aws ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=vpc-09f694f971836e5d8" \
  --profile wanthanaporn_bbtvnmd-prod \
  --region ap-southeast-1 \
  --query 'NetworkAcls[*].Entries[?RuleNumber!=`32767`].[RuleNumber,Protocol,RuleAction,CidrBlock,Egress]' \
  --output table
```

#### 4. Test Internal Connectivity
Create a test EC2 instance in the same VPC and test:
```bash
curl -I http://10.35.101.144:8080/
```

### Solution Options

#### Option 1: Access from AWS CloudShell (Recommended for Testing)
1. Go to AWS Console
2. Click CloudShell icon (top right)
3. Run: `curl https://auth-kc.bbtvnewmedia.com/`

#### Option 2: Use VPN to AWS
If your organization has AWS VPN or Direct Connect

#### Option 3: Whitelist Your IP
If there are Network ACLs blocking, add your IP:
```bash
# Get your public IP
curl ifconfig.me

# Add to Network ACL (if needed)
```

#### Option 4: Test from Mobile Network
Use mobile hotspot to bypass corporate network

### Expected Behavior When Working

When connection works, you should see:
```
HTTP/1.1 200 OK
Content-Type: text/html
```

And browser should show Keycloak welcome page or redirect to /realms/master

### Logs Confirmation

Keycloak is running correctly:
```
2026-02-02 11:01:42,920 INFO  [io.quarkus] (main) Keycloak 23.0.7 on JVM (powered by Quarkus 3.2.10.Final) started in 16.851s. Listening on: http://0.0.0.0:8080
```

### Next Steps

1. **Test from AWS CloudShell** to confirm Keycloak is accessible
2. If CloudShell works → Network issue from your location
3. If CloudShell fails → Check ALB configuration

### Quick Test Commands

```bash
# From AWS CloudShell or EC2 in same region
curl -v http://keycloak-alb-1734647026.ap-southeast-1.elb.amazonaws.com/

# Check if port 443 is reachable
nc -zv auth-kc.bbtvnewmedia.com 443

# Check DNS
nslookup auth-kc.bbtvnewmedia.com
dig auth-kc.bbtvnewmedia.com
```

### Contact Network Team

If issue persists, contact your network/security team with:
- Target: auth-kc.bbtvnewmedia.com (54.151.234.114, 13.250.194.198)
- Ports: 80, 443
- Protocol: HTTPS
- Error: Connection timeout after 10+ seconds
