"""
Health Check Lambda Function
Validates incoming requests and stores them in DynamoDB
"""
import json
import uuid
import os
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')

# Get environment variables
TABLE_NAME = os.environ.get('TABLE_NAME')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'unknown')

if not TABLE_NAME:
    raise ValueError("TABLE_NAME environment variable is required")

table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    """
    Main Lambda handler for health check endpoint
    Validates input, stores request data in DynamoDB, and returns health status
    """
    print(f"Received event: {json.dumps(event)}")

    try:
        # Parse request body (handle both direct invocation and API Gateway proxy format)
        if 'body' in event:
            # API Gateway proxy format
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
            http_method = event.get('requestContext', {}).get('http', {}).get('method', 'UNKNOWN')
            path = event.get('requestContext', {}).get('http', {}).get('path', '/')
            source_ip = event.get('requestContext', {}).get('http', {}).get('sourceIp', 'unknown')
            user_agent = event.get('headers', {}).get('user-agent', 'unknown')
        else:
            # Direct invocation format
            body = event
            http_method = 'DIRECT'
            path = '/direct'
            source_ip = 'lambda-direct'
            user_agent = 'lambda-runtime'

        # INPUT VALIDATION: Check required field
        if 'payload' not in body:
            print("Validation error: Missing 'payload' field in request body")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'error': 'Bad Request',
                    'message': 'Request body must contain "payload" field'
                })
            }

        # Generate unique request ID
        request_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()

        # Build DynamoDB item
        item = {
            'id': request_id,
            'timestamp': timestamp,
            'method': http_method,
            'path': path,
            'payload': body['payload'],
            'source_ip': source_ip,
            'user_agent': user_agent,
            'environment': ENVIRONMENT
        }

        # Store in DynamoDB
        table.put_item(Item=item)

        print(f"Successfully stored request {request_id} in DynamoDB")

        # Return success response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'status': 'healthy',
                'message': 'Request processed and saved.',
                'request_id': request_id,
                'environment': ENVIRONMENT
            })
        }

    except json.JSONDecodeError as e:
        print(f"JSON parsing error: {str(e)}")
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': 'Bad Request',
                'message': 'Invalid JSON in request body'
            })
        }

    except ClientError as e:
        print(f"DynamoDB error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': 'Internal Server Error',
                'message': 'Failed to store request data'
            })
        }

    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': 'Internal Server Error',
                'message': str(e)
            })
        }
