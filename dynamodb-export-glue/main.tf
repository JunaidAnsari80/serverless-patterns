terraform {
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region = "eu-west-1"
}

resource "aws_dynamodb_table" "dynamodb-table-users" {
  name             = "Usertable"
  billing_mode     = "PROVISIONED"
  read_capacity    = 5
  write_capacity   = 5
  hash_key         = "UserId"
  range_key        = "DepartmentId"

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "DepartmentId"
    type = "S"
  }

  tags = {
    Name        = "dynamodb-test-table"
    Environment = "dev"
  }
}

resource "aws_glue_catalog_database" "catalog-database" {
  name = "user-exporter-catalog-db"
}

resource "aws_glue_catalog_table" "catalog-table" {
  name = "user-exporter-eatalog-db-table"
  database_name = aws_glue_catalog_database.catalog-database.name
  parameters = {
    "classification" = "dynamodb"
  }
  
  storage_descriptor {
    location = aws_dynamodb_table.dynamodb-table-users.arn
  columns {
    name = "UserId"
    type ="string"
  }
  columns {
    name = "FirstName"
    type = "string"
  } 
  columns {
    name = "LastName"
    type = "string"
  }
  }
}

resource "aws_iam_role" "exporter-role" {
  name = "exporter-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "policy-awsglueservicerole" {
  role       = aws_iam_role.exporter-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "exporter-policy" {
  name = "exporter-policy"
  role = aws_iam_role.exporter-role.id
  policy = data.aws_iam_policy_document.exporter-policy-document.json
}

resource "aws_s3_bucket" "source-bucket" {
  bucket = "script-source-bucket"
}

resource "aws_s3_bucket" "export-bucket" {
  bucket = "db-export-loc"
}

resource "aws_s3_bucket_public_access_block" "source-bucket-public-access-block" {
  bucket                  = aws_s3_bucket.source-bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "export-bucket-public-access-block" {
  bucket                  = aws_s3_bucket.export-bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "glue-job-script" {
  bucket = aws_s3_bucket.source-bucket.id
  key = "User-exporter-script/User-exporter-job.py"
  source = "./jobs/User-exporter-job.py"
  etag   = filemd5("./jobs/User-exporter-job.py")
}

resource "aws_cloudwatch_log_group" "User-exporter-logs" {
  name = "User-exporter-logs"
}

resource "aws_glue_job" "job" {
  name = "User-exporter-job"
  glue_version = "4.0"
  number_of_workers = 10
  worker_type = "G.1X"
  command {
    script_location = "s3://${aws_s3_bucket.source-bucket.id}/User-exporter-script/User-exporter-job.py"
    python_version  = "3"
  }
  default_arguments = {
    "--DEST_FOLDER" = aws_s3_bucket.export-bucket.id
    "--JOB_NAME" = "User-exporter-job"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.User-exporter-logs.name
  }
  role_arn = aws_iam_role.exporter-role.arn
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "exporter-policy-document" {
    statement{
        effect= "Allow"
        actions = [
            "glue:*",
        ]
        resources = [
         "*"
        ]
    }

    statement {
      effect = "Allow"
      actions = [
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:GetBucketAcl",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      resources = [
        aws_s3_bucket.export-bucket.arn,
        "${aws_s3_bucket.export-bucket.arn}/*",
        aws_s3_bucket.source-bucket.arn,
          "${aws_s3_bucket.source-bucket.arn}/*"
      ]
    }

    statement {
        effect = "Allow"
        actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
        ] 
        resources = [
            aws_cloudwatch_log_group.User-exporter-logs.arn
        ]
    }

    statement {
      sid = "dynamodb"
      actions = [
        "dynamodb:DescribeTable",
        "dynamodb:Scan"
      ]
      effect = "Allow"
      resources = [
        aws_dynamodb_table.dynamodb-table-users.arn
      ]
    }
}