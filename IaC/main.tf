
# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA PERMS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.customer_order_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 BUCKET FOR ME
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "bucket" {
  bucket = "molocustomerorder"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.customer_order_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}


# ---------------------------------------------------------------------------------------------------------------------
# SQS QUEUE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sqs_queue" "customer_order_queue" {
    name = "results-updates-queue"
    redrive_policy  = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.customer_order_dl_queue.arn}\",\"maxReceiveCount\":5}"
    visibility_timeout_seconds = 300

    tags = {
        Environment = "dev"
    }
}


resource "aws_sqs_queue" "customer_order_dl_queue" {
    name = "results-updates-dl-queue"
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA ROLE & POLICIES
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "lambda_role" {
    name = "LambdaRole"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_logs_policy" {
    name = "LambdaRolePolicy"
    role = "${aws_iam_role.lambda_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_multiple_policies" {
    name = "AllowSQSAndDBPermissions"
    role = "${aws_iam_role.lambda_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "s3:*",
        "sqs:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lambda_function" "customer_order_lambda" {
    filename         = "../src/parse_csv.zip"
    function_name    = "parse_csv"
    role             = "${aws_iam_role.lambda_role.arn}"
    handler          = "parse_csv.lambda_handler"
    source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
    runtime          = "python3.7"

    environment {
        variables = {
            QUEUE_URL = aws_sqs_queue.customer_order_queue.url
            BUCKET_NAME = aws_s3_bucket.bucket.id

        }
    }
}

resource "aws_cloudwatch_log_group" "function_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.customer_order_lambda.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}
# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA EVENT SOURCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "customer_order_lambda_event_source" {
    event_source_arn = "${aws_sqs_queue.customer_order_queue.arn}"
    enabled          = true
    function_name    = "${aws_lambda_function.customer_order_lambda.arn}"
    batch_size       = 1
}


resource "aws_dynamodb_table" "cutomertable" {
  name             = "customerdata"
  hash_key         = "id"
  billing_mode     = "PAY_PER_REQUEST"
  attribute {
    name = "id"
    type = "S"
  }
}
