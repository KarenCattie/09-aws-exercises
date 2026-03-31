#!/usr/bin/env bash

export IMAGE=$1
AWS_REGION=$2
ECR_REGISTRY=$3

# Login to ECR
echo "Logging into ECR"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Deploy with docker-compose
echo "Deploying $IMAGE"
docker-compose -f docker-compose.yaml up --detach

echo "Deployment successful"