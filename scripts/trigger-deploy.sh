#!/usr/bin/env bash
set -Eeuo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${ARTIFACT_BUCKET:?ARTIFACT_BUCKET is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${BACKEND_REPO:?BACKEND_REPO is required}"
: "${FRONTEND_REPO:?FRONTEND_REPO is required}"

export AWS_DEFAULT_REGION="$AWS_REGION"

account_id="$(aws sts get-caller-identity --query Account --output text)"
registry="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"

backend_image="${registry}/${BACKEND_REPO}:${IMAGE_TAG}"
frontend_image="${registry}/${FRONTEND_REPO}:${IMAGE_TAG}"

instance_id="i-0979ce44516967c47"
instance_ids="$instance_id"

state="$(aws ec2 describe-instances \
  --instance-ids "$instance_id" \
  --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)"

if [[ "$state" != "running" ]]; then
  echo "ERROR: Application instance $instance_id is not running (state: $state)." >&2
  exit 1
fi

if [[ "$instance_ids" == *$'\t'* || "$instance_ids" == *' '* ]]; then
  echo "ERROR: More than one instance matched; this script expects one target." >&2
  exit 1
fi

# Create a JSON-safe payload for SSM. Secrets are fetched on the EC2 itself.
commands_json="$(
  jq -cn \
    --arg region "$AWS_REGION" \
    --arg bucket "$ARTIFACT_BUCKET" \
    --arg registry "$registry" \
    --arg backend "$backend_image" \
    --arg frontend "$frontend_image" \
    --arg tag "$IMAGE_TAG" \
    '[
      "set -eu",
      "export AWS_REGION=" + ($region | @sh),
      "export AWS_DEFAULT_REGION=" + ($region | @sh),
      "export ARTIFACT_BUCKET=" + ($bucket | @sh),
      "export ECR_REGISTRY=" + ($registry | @sh),
      "export BACKEND_IMAGE=" + ($backend | @sh),
      "export FRONTEND_IMAGE=" + ($frontend | @sh),
      "export IMAGE_TAG=" + ($tag | @sh),
      "aws s3 cp \"s3://${ARTIFACT_BUCKET}/releases/${IMAGE_TAG}/docker-compose.prod.yml\" /opt/todo-assistant/docker-compose.prod.yml",
      "aws s3 cp \"s3://${ARTIFACT_BUCKET}/releases/${IMAGE_TAG}/health-check.sh\" /opt/todo-assistant/health-check.sh",
      "aws s3 cp \"s3://${ARTIFACT_BUCKET}/releases/${IMAGE_TAG}/rollback.sh\" /opt/todo-assistant/rollback.sh",
      "aws s3 cp \"s3://${ARTIFACT_BUCKET}/releases/${IMAGE_TAG}/deploy-app.sh\" /opt/todo-assistant/deploy-app.sh",
      "chmod 0700 /opt/todo-assistant/*.sh",
      "exec /opt/todo-assistant/deploy-app.sh"
    ]'
)"

parameters="$(jq -cn --argjson commands "$commands_json" '{commands:$commands}')"

command_id="$(
  aws ssm send-command \
    --instance-ids "$instance_ids" \
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
      --instance-id "$instance_ids" \
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
        --instance-id "$instance_ids" \
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
