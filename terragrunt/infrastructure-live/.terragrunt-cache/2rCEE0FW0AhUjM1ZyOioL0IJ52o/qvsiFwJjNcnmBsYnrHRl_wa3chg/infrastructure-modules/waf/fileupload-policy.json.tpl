{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "s3",
            "Effect": "Allow",
            "Action": [
                "s3:PutObjectAcl",
                "s3:PutObject",
                "s3:ListBucketMultipartUploads",
                "s3:ListBucket",
                "s3:GetObject",
                "s3:GetBucketLocation",
                "s3:AbortMultipartUpload"
            ],
            "Resource": [
                "${s3_bucket_arn}/*",
                "${s3_bucket_arn}"
            ]
        },
        {
            "Sid": "cloudwatch",
            "Effect": "Allow",
            "Action": "logs:PutLogEvents",
            "Resource": [
                "arn:aws:logs:${region}:${account_id}:log-group:/aws/kinesisfirehose/${firehose_name}:*:*:*",
                "arn:aws:logs:${region}:${account_id}:log-group:/aws/kinesisfirehose/${firehose_name}:*"
            ]
        },
        {
            "Sid": "FirehoseKms",
            "Effect": "Allow",
            "Action": [
                "kms:GenerateDataKey",
                "kms:Decrypt"
            ],
            "Resource": "${kms_id}",
            "Condition": {
                "StringEquals": {
                    "kms:ViaService": "s3.${region}.amazonaws.com"
                },
                "StringLike": {
                    "kms:EncryptionContext:aws:s3:arn": "${s3_bucket_arn}/*"
                }
            }
        }
    ]
}
