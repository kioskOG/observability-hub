# Cross-Account AWS Log Ingestion Setup
#
# This document describes how each source account delivers logs to the
# central S3 bucket in the management account.
#
# Architecture:
#
#   ┌──────────────────────────────────────────────────────────────────┐
#   │                    Management Account (000000000001)             │
#   │                                                                  │
#   │  ┌─────────────────────────────────┐  ┌──────────────────────┐  │
#   │  │ management-wazuh-aws-logs (S3)  │  │  SQS Queue           │  │
#   │  │                                 │──│  wazuh-aws-logs-     │  │
#   │  │  AWSLogs/                       │  │  notify               │  │
#   │  │  ├── 000000000001/CloudTrail/   │  └──────────┬───────────┘  │
#   │  │  ├── 000000000002/CloudTrail/   │             │              │
#   │  │  ├── 000000000003/CloudTrail/   │             ▼              │
#   │  │  └── 000000000004/CloudTrail/   │  ┌──────────────────────┐  │
#   │  └─────────────────────────────────┘  │  Wazuh Manager (EKS) │  │
#   │                                       │  aws-s3 wodle (IRSA) │  │
#   │                                       └──────────────────────┘  │
#   └──────────────────────────────────────────────────────────────────┘
#           ▲               ▲               ▲               ▲
#           │               │               │               │
#   ┌───────┴──────┐ ┌─────┴────────┐ ┌────┴─────────┐ ┌───┴──────────┐
#   │ management   │ │ dev          │ │ prod         │ │ audit        │
#   │ 000000000001 │ │ 000000000002 │ │ 000000000003 │ │ 000000000004 │
#   │              │ │              │ │              │ │              │
#   │ CloudTrail   │ │ CloudTrail   │ │ CloudTrail   │ │ CloudTrail   │
#   │ Config       │ │ Config       │ │ Config       │ │ Config       │
#   │ GuardDuty    │ │ GuardDuty    │ │ GuardDuty    │ │ GuardDuty    │
#   │              │ │              │ │ VPC Flow     │ │              │
#   │              │ │              │ │ WAF          │ │              │
#   └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘

# ===========================================================================
# Per-Account Configuration Steps
# ===========================================================================
#
# For each source account, configure the following AWS services to deliver
# logs to the central bucket:
#
# 1. CloudTrail
#    - Create or update the trail
#    - Set S3 bucket: management-wazuh-aws-logs
#    - Set S3 prefix: AWSLogs/<ACCOUNT_ID>/CloudTrail/
#    - Enable SSE-KMS encryption (use central KMS key or account-specific)
#    - Ensure the bucket policy allows CloudTrail delivery (see bucket-policy.json)
#
# 2. AWS Config
#    - Create or update delivery channel
#    - Set S3 bucket: management-wazuh-aws-logs
#    - Set S3 prefix: AWSLogs/<ACCOUNT_ID>/Config/
#
# 3. GuardDuty
#    - Enable GuardDuty findings export to S3
#    - Set S3 bucket: management-wazuh-aws-logs
#    - Set KMS key for encryption
#    - Note: GuardDuty currently uses EventBridge → need to switch to S3 export
#
# 4. VPC Flow Logs (prod only initially)
#    - Create flow log with destination type: s3
#    - Set S3 bucket ARN: arn:aws:s3:::management-wazuh-aws-logs/AWSLogs/<ACCOUNT_ID>/VPCFlowLogs/
#
# 5. WAF Logs (prod only)
#    - Enable WAF logging via Kinesis Firehose → S3
#    - Set S3 bucket: management-wazuh-aws-logs
#    - Set S3 prefix: AWSLogs/<ACCOUNT_ID>/WAF/
#
# ===========================================================================
# Verification
# ===========================================================================
#
# After configuring each service, verify logs appear in the bucket:
#
#   aws s3 ls s3://management-wazuh-aws-logs/AWSLogs/000000000001/CloudTrail/ --recursive | head
#   aws s3 ls s3://management-wazuh-aws-logs/AWSLogs/000000000002/CloudTrail/ --recursive | head
#   aws s3 ls s3://management-wazuh-aws-logs/AWSLogs/000000000003/CloudTrail/ --recursive | head
#   aws s3 ls s3://management-wazuh-aws-logs/AWSLogs/000000000004/CloudTrail/ --recursive | head
#
# ===========================================================================
# SQS Verification
# ===========================================================================
#
# After enabling S3 event notifications on the bucket:
#
#   aws sqs get-queue-attributes \
#     --queue-url https://sqs.us-east-2.amazonaws.com/000000000001/wazuh-aws-logs-notify \
#     --attribute-names ApproximateNumberOfMessages
#
# Messages should appear within minutes of new log objects being delivered.
