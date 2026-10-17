#!/usr/bin/env bash
set -Eeuo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${ARTIFACT_BUCKET:?ARTIFACT_BUCKET is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${BACKEND_REPO:?BACKEND_REPO is required}"
: "${FRONTEND_REPO:?FRONTEND_REPO is required}"

# Secrets Manager secret ARN
SECRET_ARN="arn:aws:secretsmanager:ap-south-1:323708468684:secret:todo-assistant/production-i5yqjU"

export AWS_DEFAULT_REGION="$AWS_REGION"

for tool in aws jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $tool" >&2
    exit 1
  fi
done

account_id="$(aws sts get-caller-identity --query Account --output text)"
registry="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"

backend_image="${registry}/${BACKEND_REPO}:${IMAGE_TAG}"
frontend_image="${registry}/${FRONTEND_REPO}:${IMAGE_TAG}"

instance_id="i-0979ce44516967c47"

state="$(aws ec2 describe-instances \
  --instance-ids "$instance_id" \
  --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)"

if [[ "$state" != "running" ]]; then
  echo "ERROR: Application instance $instance_id is not running (state: $state)." >&2
  exit 1
fi

# Build a JSON-safe command payload. Secret values are retrieved on the app EC2.
commands_json="$(
  jq -cn \
    --arg region "$AWS_REGION" \
    --arg bucket "$ARTIFACT_BUCKET" \
    --arg registry "$registry" \
    --arg backend "$backend_image" \
    --arg frontend "$frontend_image" \
    --arg tag "$IMAGE_TAG" \
    --arg secretArn "$SECRET_ARN" \
    '[
      "set -eu",
      "export AWS_REGION=" + ($region | @sh),
      "export AWS_DEFAULT_REGION=" + ($region | @sh),
      "export ARTIFACT_BUCKET=" + ($bucket | @sh),
      "export ECR_REGISTRY=" + ($registry | @sh),
      "export BACKEND_IMAGE=" + ($backend | @sh),
      "export FRONTEND_IMAGE=" + ($frontend | @sh),
      "export IMAGE_TAG=" + ($tag | @sh),
      "export SECRET_ARN=" + ($secretArn | @sh),
      "install -d -o root -g root -m 0750 /opt/todo-assistant",
      "aws s3 cp \"s3://${ARTIFACT_BUCKET}/releases/${IMAGE_TAG}/docker-compose.prod.yml\" /opt/todo-assistant/docker-compose.prod.yml",
      "aws s3 cp \"s3://${ARTIFACT_BUCKET}/releases/${IMAGE_TAG}/health-check.sh\" /opt/todo-assistant/health-check.sh",
      "aws s3 cp \"s3://${ARTIFACT_BUCKET}/releases/${IMAGE_TAG}/rollback.sh\" /opt/todo-assistant/rollback.sh",
      "aws s3 cp \"s3://${ARTIFACT_BUCKET}/releases/${IMAGE_TAG}/deploy-app.sh\" /opt/todo-assistant/deploy-app.sh",
      "chown root:root /opt/todo-assistant/docker-compose.prod.yml /opt/todo-assistant/health-check.sh /opt/todo-assistant/rollback.sh /opt/todo-assistant/deploy-app.sh",
      "chmod 0600 /opt/todo-assistant/docker-compose.prod.yml",
      "chmod 0700 /opt/todo-assistant/health-check.sh /opt/todo-assistant/rollback.sh /opt/todo-assistant/deploy-app.sh",
      "exec /opt/todo-assistant/deploy-app.sh"
    ]'
)"

parameters="$(jq -cn --argjson commands "$commands_json" '{commands:$commands}')"

command_id="$(
  aws ssm send-command \
    --instance-ids "$instance_id" \
    --document-name AWS-RunShellScript \
    --comment "Deploy application release ${IMAGE_TAG}" \
    --parameters "$parameters" \
    --query 'Command.CommandId' \
    --output text
)"

echo "SSM deployment command submitted."

deadline=$((SECONDS + 900))

while (( SECONDS < deadline )); do
  status="$(
    aws ssm get-command-invocation \
      --command-id "$command_id" \
      --instance-id "$instance_id" \
      --query Status \
      --output text 2>/dev/null || true
  )"

  case "$status" in
    Success)
      echo "Remote deployment succeeded."
      exit 0
      ;;
    Failed|Cancelled|TimedOut)
      aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$instance_id" \
        --query '{Status:Status,Output:StandardOutputContent,Error:StandardErrorContent}' \
        --output json || true

      echo "ERROR: Remote deployment failed with status $status." >&2
      exit 1
      ;;
  esac

  sleep 5
done

echo "ERROR: Timed out waiting for SSM." >&2
exit 1
