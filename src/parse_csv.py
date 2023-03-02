import boto3
import csv
import json
import os
import datetime

# AWS initialization
s3 = boto3.client('s3')
sqs = boto3.client('sqs')
dynamodb = boto3.resource('dynamodb')
table_name = 'customerdata'
table = dynamodb.Table(table_name)
bucket_name = os.environ['BUCKET_NAME']
# SQS queue details
queue_url = os.environ['QUEUE_URL']


# Define function to convert CSV file to JSON format
def csv_to_json(file):
    csv_data = csv.DictReader(file)
    json_data = json.dumps([row for row in csv_data])
    return json_data

# Define function to put item into DynamoDB table


def put_item(item):
    table = dynamodb.Table(table_name)
    table.put_item(Item=item)

# Define function to send message to SQS queue


def send_message(message):
    response = sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=message
    )
    return response


# Retrieve list of objects in S3 bucket
response = s3.list_objects_v2(Bucket=bucket_name)

# main


def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        # Check if object key matches the pattern $TYPE_$DATE.csv
        if key.endswith('.csv'):
            obj_key = key.split('/')[-1]
            obj_type, obj_date = obj_key.split('.')[0].split('_')
            # Read the CSV file from S3 bucket
            file = s3.get_object(Bucket=bucket, Key=key)[
                'Body'].read().decode('utf-8')
            # Convert CSV file to JSON format
            json_data = csv_to_json(file)
            # Create item to put into DynamoDB table
            item = {
                'id': obj_key,
                'type': obj_type,
                'date': datetime.datetime.strptime(obj_date, '%Y%m%d').strftime('%Y-%m-%d'),
                'data': json_data
            }

            # Put item into DynamoDB table
            put_item(item)

            if obj_type == 'customers':
                customer_data = json.loads(json_data)
                customer_ref = customer_data[0]['customer_reference']
                num_orders = len(customer_data)
                total_spent = sum(float(row['total_amount'])
                                  for row in customer_data)
                customer_msg = {
                    'type': 'customer_message',
                    'customer_reference': customer_ref,
                    'number_of_orders': num_orders,
                    'total_amount_spent': total_spent
                }
                send_message(json.dumps(customer_msg))
            elif obj_type == 'orders':
                order_data = json.loads(json_data)
                order_ref = order_data[0]['order_reference']
                error_msg = {
                    'type': 'error_message',
                    'customer_reference': None,
                    'order_reference': order_ref,
                    'message': 'Something went wrong!'
                }
                send_message(json.dumps(error_msg))
