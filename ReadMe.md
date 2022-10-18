# Description
This project deploys the infrastructure needed for [TODO-MY-GITHUB-HERE](). An Architecture Diagram is shown below.
![Infrastructure Diagram](/files/discord-diffusion-pic.png)

# Setup
## Prerequisite Checklist
1. Create a new Discord Application.
2. Create an Amazon Elastic Container Registry (ECR) in the region you will deploy to.
3. Deploy a Docker image from the project [TODO-MY-GITHUB-HERE]() to that repository.
4. Tag your public subnets in the region you will deploy into with the tag ```Tier``` | ```Public```.
5. Fill out the terraform.tfvars and export the Discord Application Secret ```TF_VAR_discord_application_secret``` to your commandline.

## Discord Pre-Work
1. Create a Discord Application. Look online, there are great resources for this. 
    * Login to the [Discord Developers website](https://discord.com/developers/applications).
    * Create your Discord Application if you have not already. Plenty of great tutorials online.
    * Add your Discord Application to your server or create a server if you do not have one. Plenty of great tutorials online. The minimum permissions needed for generating the URL are ```applications.commands```.
2. Copy the Discord Application ID and Public key which will be used for the Terraform variables. The Public Key is used for the ```discord_application_secret``` Terraform variable. The ```discord_application_secret``` can be found under your Discord Application -> Bot -> (Enable bot in necessary) -> Token. Feel free to reset the token if you did not take note of it.
    * It is best practice to not store secrets in a plain text file that could be picked up by version control system. Below is an example to store a secret on the commandline but feel free to use your own method for securing secrets. 
    * ```export TF_VAR_discord_application_secret='YOURSECRETHERE'```

## Terraform Setup
1. Setup your commandline with the aws cli. Use ```aws config``` and fill in all the fields. The region selection should be the region you are planning to deploy into. This allows Terraform to pull the right AMI to be used in the EC2 Template generation. 
    * Documentation of the [AWS commandline](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) 
2. Setup your Terraform Variables. The Terraform.tfvars file is provided for you to fill in your variables. If you don't know what to put there, look in the "variables.tf" file in the root directory. It has descriptions there. 
    * It is assumed the user building this project already has a VPC with public subnets. In order for EC2 instances to launch, please have your subnets in the same region that you are deploying to *AND* the subnets are public to the internet. Add the following Tag to these as subnets: Key:```Tier``` and Value:```Public```. Do not add the Key: or Value: wording in the tags. This is just for clarity sake.
3. There is an assumption that ECR is already created with the image pushed to the ECR registry in the region you are deploying to. ECR should be deployed in the same region as ECS to benefit from the cost savings related to [no cross region data transfer fees](https://aws.amazon.com/blogs/containers/understanding-data-transfer-costs-for-aws-container-services/).
    * [How to create a Private Repository with Elastic Container Registry (ECR)](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html)
    * Building a Docker Image
        * Have docker installed.
        * git clone the code from [TODO-MY-GITHUB-HERE]().
        * Run the command ```docker build -t discord-diffusion .``` . Please note that this build can take excess of 15 minutes and the image is large ~14 GB. It is large due to the entire stable-diffusion model being downloaded into the container and all of the conda dependencies. I'm looking at you pytorch🤨. This can be optimized in the future but it does work.
        * Please comment on your favorite ways to containerize large container dependencies and AI models!
    * [Publishing a Docker image with ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html)

4. Run ```Terraform apply``` and have a successful deployment - easy enough? 
    * Copy the output of ```discord_interactions_endpoint_url``` to the Discord Interactions Endpoint URL on the General Information page of your Discord Application. Click 'Save'. You should have a success message at the top in green. If not, there is an issue between Discord and your infrastructure. Try checking the logs on Amazon API Gateway, and the first AWS Lambda function.

# Gotchas
1. **Service Limits:** Make sure you have enough vCPU for the 'G' EC2 instances. Put in a [Service Quota Limit Increase](https://console.aws.amazon.com/servicequotas/home) in the region you plan to deploy in if needed.
2. The project takes ~7 minutes after receiving a message to scale up an instance and get the ECS task running. It takes another minute or so before an instance is ready to start taking requests.

# Architecture Decisions
1. **ECS EC2 instances are deployed in a public subnet**. 
    * Pros: 
        * Paying less for data transfers.
    * Cons: 
        * Less secure
    * This was done to reduce cost so there would not be a NAT Gateway. A NAT Gateway that runs $0.045 per hour and adds $0.045 per GB processed. The NAT Gateway is not a huge expense considering g4dn.xlarge run around 50 cents an hour. But when running one instance for a maximum of 4 hours a day, the NAT Gateway charges do make somewhat of an impact.
2. **All of the code is packaged into a relatively large 14GB container**. 
    * Pros: 
        * Source code is in one place
        * No managing custom AMIs
    * Cons: 
        * Big containers
        * Long deployment times (~7 minutes)
    * Can confidently deploy the image every time. No managing custom AMIs. No Updating the AMI every time there is a change in the source code, all changes just require a new container deployment.
3. **Focus on Serverless**
    * Pros: 
        * Less to manage
        * Easy to scale
        * Pay for what you use
    * Cons:
        * Less control of underlying services
        * Potential to be locked into a vendor
    * This project relies heavily on AWS serverless offerings: Amazon API Gateway, AWS Lambda, Amazon Simple Queue Service, Amazon Eventbridge, AWS Step Functions, Amazon CloudWatch Metrics, Amazon CloudWatch Alarms.
4. **ECS uses EC2**:
    * This was necessary as stable-diffusion requires a GPU for processing images in a reasonable time frame. At the current time of writing, there are no serverless options with a GPU. [AWS Fargate does not support GPUs](https://github.com/aws/containers-roadmap/issues/88). AWS Lambda also does not support GPUs.

# Scalability In Mind
How many requests per second could this infrastructure handle with one deployment? With one deployment of this project and given enough service quota increases, this project could likely handle 150 requests per second, or 388,800,000 requests a month, or 1,555,200,000 images! Side note: :hammer: If you actually run into this to the limit, make a note of it!
* The limit likely to be hit first is the message throughput of [300 API calls per second](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-messages.html) for SQS fifo queues. At any one moment in time there could be a message being sent, and received. Which would be a maximum of 150 messages per second. This could easily be overcome by using High Throughput for FIFO queues, which increases the throughput to 3,000 API calls per second.
* Lets run the numbers with a High Throughput FIFO queue. ```5000 requests / 20 seconds processing per request = 250 requests per second```. This is due to an ECS limitation of [5,000 Container instances per cluster](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-quotas.html). This gives a maximum of 250 requests per second or 648,000,000 requests a month.

# Future Improvements
1. This project does not take advantage of Spot instances. I would recommend adding Spot Instances and taking advantage of the savings they provide. Don't forget to check your Service Quotas before using Spot instances for the 'G' Instance class.
2. This project could make the ECR Private repository.
3. There is always something to improve for someone's use case. I do need some time to walk my dogs, pet my cats, and window shop RTX 4090s.

# Thank You
Thank you Tahir Saeed for making the draw.io of the Architecture Diagram. 
Thank you Tom Diepenbrock for the conversion to Express Workflows for the Step Function.