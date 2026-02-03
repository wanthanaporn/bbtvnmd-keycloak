#!/bin/bash
# Test Keycloak from AWS CloudShell
# Run this in AWS Console → CloudShell

echo "=== Testing Keycloak Connectivity ==="
echo ""

echo "1. Testing ALB DNS (HTTP):"
curl -I --max-time 10 http://keycloak-alb-1734647026.ap-southeast-1.elb.amazonaws.com/
echo ""

echo "2. Testing Domain (HTTPS):"
curl -I --max-time 10 https://auth-kc.bbtvnewmedia.com/
echo ""

echo "3. Testing Keycloak Health:"
curl --max-time 10 http://keycloak-alb-1734647026.ap-southeast-1.elb.amazonaws.com/health/ready
echo ""

echo "4. Testing Keycloak Welcome Page:"
curl --max-time 10 http://keycloak-alb-1734647026.ap-southeast-1.elb.amazonaws.com/ | head -20
echo ""

echo "=== Test Complete ==="
