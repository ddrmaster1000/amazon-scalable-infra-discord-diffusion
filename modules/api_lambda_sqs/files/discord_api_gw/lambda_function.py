import json

from nacl.signing import VerifyKey
from nacl.exceptions import BadSignatureError
import os
import boto3
import requests
import random
import time
import datetime

lambda_client = boto3.client('lambda')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get("DYNAMODB"))

# Create SQS client
sqs = boto3.client('sqs')
QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
APPLICATION_ID = os.environ.get("APPLICATION_ID")

PUBLIC_KEY = os.environ.get("PUBLIC_KEY") # found on Discord Application -> General Information page
RESPONSE_TYPES =  { 
                    "PONG": 1, 
                    "CHANNEL_MESSAGE_WITH_SOURCE": 4,
                    "DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE": 5,
                    "DEFERRED_UPDATE_MESSAGE": 6,
                    "UPDATE_MESSAGE": 7,
                    "APPLICATION_COMMAND_AUTOCOMPLETE_RESULT": 8,
                    "MODAL": 9
                  }

def sqsMessageCleaning(customer_data, it_id, it_token, user_id, username, application_id):
    MyMessageAttributes = {}
    for customer_request in customer_data:
        MyMessageAttributes[customer_request] = {
                'DataType': 'String',
                'StringValue': str(customer_data[customer_request])
            }
    MyMessageAttributes.update({
        'interactionId': {
            'DataType': 'String',
            'StringValue': str(it_id)
        },
        'interactionToken': {
            'DataType': 'String',
            'StringValue': str(it_token)
        },
        'userId': {
            'DataType': 'Number',
            'StringValue': str(user_id)
        },
        'username': {
            'DataType': 'String',
            'StringValue': str(username)
        },
        'applicationId': {
            'DataType': 'String',
            'StringValue': str(application_id)
        },
    })
    return MyMessageAttributes
    
def sendSQSMessage(MyMessageAttributes, user_id):
    # Send message to SQS queue
    response = sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageAttributes=MyMessageAttributes,
        MessageBody=json.dumps(MyMessageAttributes),
        # Each request gets processed randomly
        # MessageGroupId=f'{user_id}{random.randint(0,99999)}'
        # Each request is processed one at a time for a user. Multiple user requests are processed at once if > 1 machine.
        MessageGroupId=user_id
    )
    # print(response['MessageId'])
    return MyMessageAttributes

def verify_signature(event):
    raw_body = event.get("body")
    auth_sig = event['headers'].get('x-signature-ed25519')
    auth_ts  = event['headers'].get('x-signature-timestamp')
    
    message = auth_ts.encode() + raw_body.encode()
    verify_key = VerifyKey(bytes.fromhex(PUBLIC_KEY))
    verify_key.verify(message, bytes.fromhex(auth_sig)) # raises an error if unequal

def ping_pong(body):
    if body.get("type") == 1:
        return True
    return False
    
def getCustomerData(discord_raw):
    customer_data = {}
    for customer_input in range(0, len(discord_raw['data']['options'])):
        customer_data[discord_raw['data']['options'][customer_input]['name']] = discord_raw['data']['options'][customer_input]['value']
    return customer_data

def validateRequest(r):
    if not r.ok:
        print("Failure")
        raise Exception(r.text)
    else:
        print("Success")
    return

def dynamodbPutItem(customer_data):
    cleaned_customer_data = {}
    # Add customer values to the cleaned data
    for key_id in customer_data:
        if key_id == "interactionToken":
            continue
        cleaned_customer_data[key_id] = customer_data[key_id]['StringValue']
    
    # Add Time
    value = datetime.datetime.fromtimestamp(time.time())
    my_time = value.strftime('%Y-%m-%d %H:%M:%S')
    cleaned_customer_data['interactionId'] = f"{my_time}%{cleaned_customer_data['userId']}"
    cleaned_customer_data['timestamp'] = my_time
    print(f"Message Data: {customer_data}")
    print(f"Cleaned Customer Data: {cleaned_customer_data}")
    table.put_item(
        Item=cleaned_customer_data
    )

def decideInputs(user_dict):
    default_dict = {
        'seed': random.randint(0,99999),
        'steps': 16,
        'sampler': "k_euler_a",
        'model': "stable_diffusion"
    }

    for internal_var, default in default_dict.items():
        if internal_var not in user_dict:
            user_dict[internal_var] = default
    return user_dict

def messageResponse(customer_data):
    # Make the customer request readable
    message_response = ''
    readable_dict = {
        'prompt': 'Prompt',
        'negative_prompt': 'Negative Prompt',
        'seed': 'Seed',
        'steps': 'Steps',
        'sampler': 'Sampler',
        'model': 'model'
    }

    # Create a human readable output
    for internal_var, readable in readable_dict.items():
        if internal_var in customer_data:
            message_response += f"{readable}: {customer_data[internal_var]}\n"
    return message_response

def lambda_handler(event, context):
    try:
        print(f"{event}") # debug print
        # verify the signature
        try:
            verify_signature(event)
        except Exception as e:
            print("[UNAUTHORIZED] Invalid request signature")
            return {
                "statusCode": 401,
                "body": "invalid request signature"
            }
            
        # check if message is a ping
        body = json.loads(event['body'])
        # print(body)
        if body.get("type") == 1:
            print("PONG")
            return {'type': 1}
        
        # Collect customer data
        info = json.loads(event.get("body"))
        # print(info)
        customer_data = getCustomerData(info)
        
        # Trigger async lambda for picture generation
        # print(f"Payload = {info}")
        # lambda_client.invoke(FunctionName='discord_stable_diffusion_backend',
                            #  InvocationType='Event',
                            #  Payload=json.dumps(info))
        
        # Send work to SQS Queue
        it_id = info['id']  
        it_token = info['token']
        user_id = info['member']['user']['id']
        username = info['member']['user']['username']
        customer_data = decideInputs(customer_data)
        sqs_message = sqsMessageCleaning(customer_data, it_id, it_token, user_id, username, APPLICATION_ID)
        sendSQSMessage(sqs_message, user_id)
        message_response = messageResponse(customer_data)
        dynamodbPutItem(sqs_message)
        # Respond to user
        print("Going to return some data!")
        return {
                "type": RESPONSE_TYPES['CHANNEL_MESSAGE_WITH_SOURCE'],
                "data": {
                    "tts": False,
                    "content": f"Submitted to Sparkle```{message_response}```",
                    "embeds": [],
                    "allowed_mentions": { "parse": [] }
                }
            }
    except:
                
        return {
            "type": RESPONSE_TYPES['CHANNEL_MESSAGE_WITH_SOURCE'],
            "data": {
                "tts": False,
                "content": f"Sorry, we are having issues processing requests right now. Come back later :slight_smile: ",
                "embeds": [],
                "allowed_mentions": { "parse": [] }
            }
        }