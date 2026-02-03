#!/bin/bash

set -e

# Configuration
AWS_REGION="ap-southeast-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY="bbtvnmd-keycloak"
IMAGE_TAG="${1:-latest}"

# ECR URI
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"

echo "=========================================="
echo "Building and Pushing Keycloak to ECR"
echo "=========================================="
echo "AWS Account: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "Repository: ${ECR_REPOSITORY}"
echo "Image Tag: ${IMAGE_TAG}"
echo "ECR URI: ${ECR_URI}"
echo "=========================================="

# Create ECR repository if it doesn't exist
echo "Checking ECR repository..."
if ! aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_REGION} 2>/dev/null; then
    echo "Creating ECR repository: ${ECR_REPOSITORY}"
    aws ecr create-repository \
        --repository-name ${ECR_REPOSITORY} \
        --region ${AWS_REGION} \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256
    
    # Set lifecycle policy
    aws ecr put-lifecycle-policy \
        --repository-name ${ECR_REPOSITORY} \
        --region ${AWS_REGION} \
        --lifecycle-policy-text '{
            "rules": [{
                "rulePriority": 1,
                "description": "Keep last 10 images",
                "selection": {
                    "tagStatus": "any",
                    "countType": "imageCountMoreThan",
                    "countNumber": 10
                },
                "action": {
                    "type": "expire"
                }
            }]
        }'
else
    echo "ECR repository already exists"
fi

# Authenticate Docker to ECR
echo "Authenticating to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}

# Build Docker image for x86_64 (amd64) - Fargate compatible
echo "Building Docker image for x86_64/amd64..."
docker buildx build --platform linux/amd64 -t ${ECR_REPOSITORY}:${IMAGE_TAG} .

# Tag image for ECR
echo "Tagging image..."
docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}

# Push to ECR
echo "Pushing image to ECR..."
docker push ${ECR_URI}:${IMAGE_TAG}

echo "=========================================="
echo "Successfully pushed image to ECR!"
echo "Image URI: ${ECR_URI}:${IMAGE_TAG}"
echo "=========================================="
