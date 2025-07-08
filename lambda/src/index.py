import base64
import boto3
import json
import os
import requests
import urllib
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from typing import Dict, Any, Optional
from pydantic import BaseModel, ValidationError
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)



# Pydantic models for validation
class SNSMessage(BaseModel):
    Message: str
    MessageId: str
    Subject: Optional[str] = None
    TopicArn: str
    Timestamp: str

class SNSRecord(BaseModel):
    EventSource: str = "aws:sns"
    EventVersion: str
    EventSubscriptionArn: str
    Sns: SNSMessage

class SNSEvent(BaseModel):
    Records: list[SNSRecord]

class ExtractedSNSData(BaseModel):
    message: str
    messageId: str
    subject: str
    payload: dict
    parsedMessage: Optional[dict] = None

class PubSubResponse(BaseModel):
    success: bool
    statusCode: int
    messageIds: Optional[list[str]] = None
    message: Optional[str] = None

class GCPTokenResponse(BaseModel):
    access_token: str
    issued_token_type: str
    token_type: str
    expires_in: int

def create_token_aws(project_number: str, pool_id: str, provider_id: str, 
                    role_arn: str, role_session_name: str, gcp_project: str) -> str:
    """
    Creates AWS session token and formats it for GCP consumption.
    
    Args:
        project_number: GCP project number
        pool_id: Workload identity pool ID
        provider_id: Provider ID
        role_arn: AWS role ARN to assume
        role_session_name: Session name for role assumption
        gcp_project: GCP project ID
        
    Returns:
        URL-encoded token string
    """
    try:
        # Create STS client and assume role
        sts_role_client = boto3.client('sts')
        sts_role_values = sts_role_client.assume_role(
            RoleArn=role_arn,
            RoleSessionName=role_session_name
        )
        
        # Extract credentials
        credentials = sts_role_values['Credentials']
        access_key_id = credentials['AccessKeyId']
        secret_access_key = credentials['SecretAccessKey']
        session_token = credentials['SessionToken']
        
        logger.info(f"Successfully assumed role: {sts_role_values['AssumedRoleUser']['Arn']}")
        
        # Prepare GetCallerIdentity request
        request = AWSRequest(
            method="POST",
            url="https://sts.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15",
            headers={
                "Host": "sts.amazonaws.com",
                "x-goog-cloud-target-resource": f"//iam.googleapis.com/projects/{gcp_project}/locations/global/workloadIdentityPools/{pool_id}/providers/{provider_id}",
            },
        )
        
        # Sign the request
        session = boto3.Session(
            aws_access_key_id=access_key_id,
            aws_secret_access_key=secret_access_key,
            aws_session_token=session_token
        )
        SigV4Auth(session.get_credentials(), "sts", "us-east-1").add_auth(request)
        
        # Create token from signed request
        token = {"url": request.url, "method": request.method, "headers": []}
        for key, value in request.headers.items():
            token["headers"].append({"key": key, "value": value})
        
        return urllib.parse.quote(json.dumps(token))
        
    except Exception as e:
        logger.error(f"Error creating AWS token: {str(e)}")
        raise

def extract_sns_data(event: Dict[str, Any]) -> ExtractedSNSData:
    """
    Extract message, messageId, payload, and subject from SNS event.
    
    Args:
        event: Lambda event containing SNS records
        
    Returns:
        ExtractedSNSData object with parsed SNS data
    """
    try:
        # Validate event structure
        validated_event = SNSEvent(**event)
        
        # Process first record
        record = validated_event.Records[0]
        sns = record.Sns
        
        # Extract required fields
        sns_data = {
            'message': sns.Message,
            'messageId': sns.MessageId,
            'subject': sns.Subject or '',
            'payload': sns.dict()
        }
        
        # Try to parse message as JSON
        try:
            message_content = json.loads(sns_data['message'])
            sns_data['parsedMessage'] = message_content
        except json.JSONDecodeError:
            logger.info("Message is not valid JSON, keeping as string")
            sns_data['parsedMessage'] = None
        
        return ExtractedSNSData(**sns_data)
        
    except ValidationError as e:
        logger.error(f"Invalid SNS event structure: {str(e)}")
        raise
    except Exception as e:
        logger.error(f"Error extracting SNS data: {str(e)}")
        raise

def send_to_pubsub(sns_data: ExtractedSNSData, bearer_token: str) -> PubSubResponse:
    """
    Repackages SNS payload into base64 encoded data and sends API call to Pub/Sub.
    
    Args:
        sns_data: Extracted SNS data
        bearer_token: GCP bearer token for authentication
        
    Returns:
        PubSubResponse with success status and details
    """
    try:
        # Get environment variables
        topic_name = os.environ.get('pubsub_topic_name')
        project_id = os.environ.get('gcp_project_id')
        
        if not topic_name or not project_id:
            raise ValueError("Missing required environment variables: pubsub_topic_name or gcp_project_id")
        
        # Pub/Sub REST API endpoint
        url = f"https://pubsub.googleapis.com/v1/projects/{project_id}/topics/{topic_name}:publish"
        
        # Prepare message data
        message_data = {
            'message': sns_data.message,
            'messageId': sns_data.messageId,
            'subject': sns_data.subject,
            'originalPayload': sns_data.payload
        }
        
        # Encode message data as base64 (required by Pub/Sub)
        message_json = json.dumps(message_data)
        encoded_data = base64.b64encode(message_json.encode('utf-8')).decode('utf-8')
        
        # Prepare Pub/Sub message
        pubsub_message = {
            'messages': [
                {
                    'data': encoded_data,
                    'attributes': {
                        'source': 'aws-sns',
                        'messageId': sns_data.messageId,
                        'subject': sns_data.subject or 'no-subject'
                    }
                }
            ]
        }
        
        # Headers
        headers = {
            'Authorization': f'Bearer {bearer_token}',
            'Content-Type': 'application/json'
        }
        
        # Make the API call
        logger.info(f"Sending message to Pub/Sub topic: {topic_name}")
        response = requests.post(url, headers=headers, json=pubsub_message)
        
        if response.status_code == 200:
            message_ids = response.json().get('messageIds', [])
            logger.info(f"Successfully sent message to Pub/Sub. Message IDs: {message_ids}")
            return PubSubResponse(
                success=True,
                messageIds=message_ids,
                statusCode=response.status_code
            )
        else:
            error_msg = f"Pub/Sub API call failed: {response.status_code} - {response.text}"
            logger.error(error_msg)
            return PubSubResponse(
                success=False,
                statusCode=response.status_code,
                message=error_msg
            )
            
    except Exception as e:
        logger.error(f"Error sending to Pub/Sub: {str(e)}")
        return PubSubResponse(
            success=False,
            statusCode=500,
            message=f"Internal error: {str(e)}"
        )

def req_gcp_token(token: str, audience: str, event: Dict[str, Any], project_number: str) -> Dict[str, Any]:
    """
    Request GCP access token using AWS token and process SNS event.
    
    Args:
        token: AWS token
        audience: GCP audience string
        event: Lambda event
        project_number: GCP project number
        
    Returns:
        Response from Pub/Sub operation
    """
    try:
        url = "https://sts.googleapis.com/v1/token"
        
        payload = {
            "audience": audience,
            "grantType": "urn:ietf:params:oauth:grant-type:token-exchange",
            "subjectToken": token,
            "requestedTokenType": "urn:ietf:params:oauth:token-type:access_token",
            "scope": "https://www.googleapis.com/auth/cloud-platform",
            "subjectTokenType": "urn:ietf:params:aws:token-type:aws4_request"
        }
        
        headers = {'Content-Type': 'application/json'}
        
        logger.info("Requesting GCP access token")
        response = requests.post(url, headers=headers, json=payload)
        
        if response.status_code != 200:
            error_msg = f"Failed to get GCP token: {response.status_code} - {response.text}"
            logger.error(error_msg)
            return {
                'success': False,
                'statusCode': response.status_code,
                'message': error_msg
            }
        
        # Validate token response
        token_response = GCPTokenResponse(**response.json())
        bearer_token = token_response.access_token
        
        logger.info("Successfully obtained GCP access token")
        
        # Extract SNS data and send to Pub/Sub
        sns_data = extract_sns_data(event)
        return send_to_pubsub(sns_data, bearer_token).dict()
        
    except ValidationError as e:
        logger.error(f"Invalid GCP token response: {str(e)}")
        return {
            'success': False,
            'statusCode': 400,
            'message': f"Invalid token response: {str(e)}"
        }
    except Exception as e:
        logger.error(f"Error in req_gcp_token: {str(e)}")
        return {
            'success': False,
            'statusCode': 500,
            'message': f"Internal error: {str(e)}"
        }

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler function.
    
    Args:
        event: Lambda event
        context: Lambda context
        
    Returns:
        Response dictionary
    """
    try:
        # Get required environment variables
        required_env_vars = [
            'project_number', 'pool_id', 'provider_id', 
            'role_arn', 'role_session_name'
        ]
        
        env_vars = {}
        for var in required_env_vars:
            value = os.environ.get(var)
            if not value:
                raise ValueError(f"Missing required environment variable: {var}")
            env_vars[var] = value
        
        logger.info("Starting Lambda execution")
        
        # Create AWS token
        token = create_token_aws(
            project_number=env_vars['project_number'],
            pool_id=env_vars['pool_id'],
            provider_id=env_vars['provider_id'],
            role_arn=env_vars['role_arn'],
            role_session_name=env_vars['role_session_name'],
            gcp_project=env_vars['project_number']
        )
        
        # Create audience string
        audience = f"//iam.googleapis.com/projects/{env_vars['project_number']}/locations/global/workloadIdentityPools/{env_vars['pool_id']}/providers/{env_vars['provider_id']}"
        logger.info(f"Using audience: {audience}")
        
        # Process token and send to Pub/Sub
        return_value = req_gcp_token(token, audience, event, env_vars['project_number'])
        
        logger.info(f"Lambda execution completed. Result: {return_value}")
        return return_value
        
    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        return {
            'success': False,
            'statusCode': 500,
            'message': f"Lambda execution failed: {str(e)}"
        }

