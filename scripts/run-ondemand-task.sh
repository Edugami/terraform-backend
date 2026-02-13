#!/bin/bash

# ============================================================================
# Run ECS On-Demand Task and Connect via ECS Exec
# ============================================================================
# Usage: ./scripts/run-ondemand-task.sh <environment>
# Example: ./scripts/run-ondemand-task.sh dev
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if environment is provided
if [ -z "$1" ]; then
  echo -e "${RED}Error: Environment not specified${NC}"
  echo "Usage: $0 <environment>"
  echo "Example: $0 dev"
  exit 1
fi

ENV=$1
CLUSTER_NAME="edugami-cluster"
TASK_FAMILY="edugami-${ENV}-ondemand"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ECS On-Demand Task Runner${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Environment: ${ENV}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Task Family: ${TASK_FAMILY}"
echo ""

# Get Terraform outputs
echo -e "${YELLOW}Reading Terraform configuration...${NC}"
cd "$(dirname "$0")/../environments/${ENV}"

SUBNETS=$(terraform output -json private_app_subnet_ids 2>/dev/null | jq -r '. | join(",")')
SECURITY_GROUPS=$(terraform output -raw app_security_group_id 2>/dev/null)

if [ -z "$SUBNETS" ] || [ -z "$SECURITY_GROUPS" ]; then
  echo -e "${RED}Error: Could not read Terraform outputs${NC}"
  echo "Make sure you're in the correct directory and Terraform has been applied"
  exit 1
fi

cd - > /dev/null

echo -e "${GREEN}✓ Configuration loaded${NC}"
echo ""

# Run the task
echo -e "${YELLOW}Starting ECS task...${NC}"
TASK_ARN=$(aws ecs run-task \
  --cluster "${CLUSTER_NAME}" \
  --task-definition "${TASK_FAMILY}" \
  --launch-type FARGATE \
  --enable-execute-command \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SECURITY_GROUPS}],assignPublicIp=DISABLED}" \
  --query 'tasks[0].taskArn' \
  --output text)

if [ -z "$TASK_ARN" ]; then
  echo -e "${RED}Error: Failed to start task${NC}"
  exit 1
fi

TASK_ID=$(echo $TASK_ARN | awk -F/ '{print $NF}')
echo -e "${GREEN}✓ Task started: ${TASK_ID}${NC}"
echo ""

# Wait for task to be running
echo -e "${YELLOW}Waiting for task to be running...${NC}"
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  TASK_STATUS=$(aws ecs describe-tasks \
    --cluster "${CLUSTER_NAME}" \
    --tasks "${TASK_ARN}" \
    --query 'tasks[0].lastStatus' \
    --output text)

  if [ "$TASK_STATUS" = "RUNNING" ]; then
    echo -e "${GREEN}✓ Task is running${NC}"
    break
  elif [ "$TASK_STATUS" = "STOPPED" ]; then
    echo -e "${RED}Error: Task stopped unexpectedly${NC}"
    echo "Check CloudWatch Logs: /ecs/edugami-${ENV}/ondemand"
    exit 1
  fi

  echo "Status: ${TASK_STATUS} (waiting...)"
  sleep 2
  ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo -e "${RED}Error: Task did not start within expected time${NC}"
  exit 1
fi

echo ""

# Connect to the task
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Connecting to task...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}You are now connected to the Rails container.${NC}"
echo -e "${YELLOW}Available commands:${NC}"
echo "  - bundle exec rails console"
echo "  - bundle exec rake db:migrate"
echo "  - bundle exec rails runner 'puts User.count'"
echo "  - psql \$DATABASE_URL"
echo ""
echo -e "${YELLOW}Type 'exit' to disconnect and stop the task.${NC}"
echo ""

# Execute command in the container
aws ecs execute-command \
  --cluster "${CLUSTER_NAME}" \
  --task "${TASK_ARN}" \
  --container "ondemand" \
  --interactive \
  --command "/bin/bash"

# After exiting, ask if user wants to stop the task
echo ""
echo -e "${YELLOW}Do you want to stop the task? (y/n)${NC}"
read -r RESPONSE

if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
  echo -e "${YELLOW}Stopping task...${NC}"
  aws ecs stop-task \
    --cluster "${CLUSTER_NAME}" \
    --task "${TASK_ARN}" \
    --reason "User requested stop" > /dev/null
  echo -e "${GREEN}✓ Task stopped${NC}"
else
  echo -e "${YELLOW}Task is still running: ${TASK_ID}${NC}"
  echo "To stop it later, run:"
  echo "  aws ecs stop-task --cluster ${CLUSTER_NAME} --task ${TASK_ARN}"
fi

echo ""
echo -e "${GREEN}Done!${NC}"
