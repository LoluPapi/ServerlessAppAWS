# Terraform ServerlessAppAWS for Parsing CSV and Storing as JSON

The following is an AWS infrastructure as code tutorial using Terraform.


## Architecture

S3 --> LAMBDA --> SQS --> DynamoDB


## Description

The code creates four resources:

1) A S3 bucket that can store csv files
2) A Lambda function that will parse csv to Json to send to SQS and DynamoDB
3) A DynamoDB to save the JSON output
4) A SQS queue

The solution consists of a Lambda function written in Python that is triggered by an S3 event when a new CSV file is uploaded to the bucket. The Lambda function reads the CSV file from the S3 bucket, converts it to JSON format, and stores the converted data in a DynamoDB table. The Lambda function then creates a customer or error message based on the type of data in the CSV file and sends it to an SQS queue.

The code has been written to scale by creating a DynamoDB table with on-demand billing mode, which means that the table will automatically scale up or down based on the number of read and write requests. The SQS queue is also designed to handle large volumes of messages, and AWS provides a scalable and reliable infrastructure for this purpose.


## How to run

Prequisties
- Terraform
- AWS Account

Navigate to the IaC folder and run `terraform init` and `terraform apply`
After it applies, upload a csv to S3 bucket and this should trigger the lambda to start processing the file. You will see the output stored in DynamoDB

If you need to make changes to the python script, look in the "src" folder. You can further add more error handling or make any other changes depending on your needs.

## To improve the setup, we can consider the following:

- Use AWS Glue to transform the data in the CSV file to the desired format instead of writing a custom function to convert CSV to JSON. Glue is a fully managed ETL (extract, transform, and load) service that can be used to prepare and load data from various sources into data stores like DynamoDB.

- Use Amazon Kinesis Data Streams to handle large volumes of data in real-time. This would help scale.

- Use Eventbridge to handle multiple APIs trying to consume the processed data.

- Implement authentication and authorization mechanisms to restrict access to the S3 bucket, DynamoDB table, and SQS queue. 

- Add more Monitoring for the Lambda function, DynamoDB table, and SQS queue using CloudWatch metrics, logs, and alarms. 