import boto3
import datetime
import dateutil
import math

# Based off of https://github.com/emre141/sqs-based-ecs-service-asg and their work

def lambda_handler(event, context):
    sqs_client = boto3.client('sqs')
    cw_client = boto3.client('cloudwatch')
    ecs_client = boto3.client('ecs')
    queue_name = event['queueName']
    queue_url = event['queueUrl']
    account_id = event['accountId']
    service_name = event['service_name']
    cluster = event["cluster_name"]
    acceptable_latency = (event["acceptable_latency"])
    time_process_per_message = (event["time_process_per_message"])
    queue_attribute_calculation(cw_client, sqs_client, ecs_client, cluster, service_name, acceptable_latency,
                                time_process_per_message, queue_url, queue_name)


def queue_attribute_calculation(cw_client, sqs_client, ecs_client, cluster, service_name, acceptable_latency,
                                time_process_per_message, queue_url, queue_name):
    acceptablebacklogpercapacityunit = int((int(acceptable_latency) / float(time_process_per_message)))
    response = ecs_client.describe_services(cluster=cluster, services=[service_name])
    # print(response)
    # Get correct service
    service_num = 0
    for service_i in range(0, len(response['services'])):
        if response['services'][service_i]['serviceName'] == service_name:
            service_num = service_i
            break
    try:    
        desired_task_count = int(response['services'][service_num]['desiredCount'])
        print(f"Running Task: {desired_task_count}")
    except IndexError:
        desired_task_count = 0
        print("[WARNING]: Service is not available, defaulting Task to 0.")
    message_count = sqs_client.get_queue_attributes(QueueUrl=queue_url, AttributeNames=['ApproximateNumberOfMessages', 'ApproximateNumberOfMessagesNotVisible'])
    datapoint_for_sqs_attribute = int(message_count['Attributes']['ApproximateNumberOfMessages']) + int(message_count['Attributes']['ApproximateNumberOfMessagesNotVisible'])
    
    print(f"Queue Message Count: {datapoint_for_sqs_attribute}")

    # """
    # Backlog Per Capacity Unit  Queue Size (ApproximateNumberofMessageVisible / Running Capacity of ECS Task Count)
    # """
    # # If no tasks are running, then we having nothing going. We need to scale up.
    # if desired_task_count == 0 and datapoint_for_sqs_attribute > 0:
    #     backlog_per_capacity_unit = datapoint_for_sqs_attribute
    #     scale_adjustment = 1
    # else:
    # # We have a process running, perform capacity math
    #     try:
    #         backlog_per_capacity_unit = datapoint_for_sqs_attribute / desired_task_count
    #     except ZeroDivisionError as err:
    #         print(f'Handling run-time error: {err}')
    #         backlog_per_capacity_unit = datapoint_for_sqs_attribute
    #     print(f"Backlog Per Capacity Unit: {backlog_per_capacity_unit}")
        
    #     try:
    #         # Scale Adjustement
    #         scale_adjustment = float(backlog_per_capacity_unit / acceptablebacklogpercapacityunit)
    #     except ZeroDivisionError as err:
    #         print('Handling run-time error:', err)
    #         scale_adjustment = 0
    
    
    desired_num_tasks = math.ceil(datapoint_for_sqs_attribute/acceptablebacklogpercapacityunit)
    print(f"Desired Number of Taks: {desired_num_tasks}")
    scale_adjustment = desired_num_tasks - desired_task_count
    print(f"Scale Number of Tasks: {scale_adjustment}")


    """
    Acceptable backlog per capacity unit = Acceptable Message Processing Latency (seconds) / Average time to Process a Message each Task (seconds)
    """
    """
    Scale UP adjustment and Scale Down Adjustment
    """


    # print("Scale Up and Down  Adjustment: " + str(scale_adjustment))
    # print("Acceptable backlog per capacity unit: " + str(acceptablebacklogpercapacityunit))
    # print("Backlog Per Capacity Unit: " + str(backlog_per_capacity_unit))
    putMetricToCW(cw_client, 'SQS', queue_name, 'ApproximateNumberOfMessages', int(datapoint_for_sqs_attribute),
                  'SQS Based Scaling Metrics')
    # putMetricToCW(cw_client, 'SQS', queue_name, 'BackLogPerCapacityUnit', backlog_per_capacity_unit,
    #               'SQS Based Scaling Metrics')
    # putMetricToCW(cw_client, 'SQS', queue_name, 'AcceptableBackLogPerCapacityUnit', acceptablebacklogpercapacityunit,
    #               'SQS Based Scaling Metrics')
    putMetricToCW(cw_client, 'SQS', queue_name, 'ScaleAdjustmentTaskCount', scale_adjustment,
                  'SQS Based Scaling Metrics')
    putMetricToCW(cw_client, 'SQS', queue_name, 'DesiredTasks', desired_num_tasks,
                  'SQS Based Scaling Metrics')


def putMetricToCW(cw, dimension_name, dimension_value, metric_name, metric_value, namespace):
    cw.put_metric_data(
        Namespace=namespace,
        MetricData=[{
            'MetricName': metric_name,
            'Dimensions': [{
                'Name': dimension_name,
                'Value': dimension_value
            }],
            'Timestamp': datetime.datetime.now(dateutil.tz.tzlocal()),
            'Value': metric_value
        }]
    )

if __name__ == "__main__":
    # event = {
    #   "queueUrl": "https://sqs.us-west-1.amazonaws.com/710440188130/discord-diffusion-dev.fifo",
    #   "queueName": "discord-diffusion-dev.fifo",
    #   "accountId": "710440188130",
    #   "service_name": "discord-diffusion-dev",
    #   "cluster_name": "discord-diffusion-dev",
    #   "acceptable_latency": "90",
    #   "time_process_per_message": "15"
    # }
    # context = []
    lambda_handler(event, context)