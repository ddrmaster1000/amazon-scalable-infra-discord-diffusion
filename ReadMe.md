# Setup Instructions
Login to the discord developers website. 
Create a Discord bot. - Look online to do this.
Add the app to a server - Look online to do this.  
Make sure you create a Bot in Discord. This is needed by the ```discord_bot_secret``` Terraform variable.
Copy Application ID and Public key for the terraform apply
Best practice to store secret by commandline at a minimum. Never has it as plain text! ```export TF_VAR_discord_application_secret='YOURSECRETHERE'```

After running ```terraform apply```, copy the output of ```discord_interactions_endpoint_url``` to the discord Interactions Endpoint URL on the General Information page of your Discord Application. Click 'Save'. 

There is an assumption that ECR is already created with the image pushed to the ECR registry. Make sure you keep the ECR in the same region as ECS to have cost savings related to cross region data transfer.
## TODO: Here we explain how to build an image, and push it to ECR.

# Architecture
Note that the ECS machines are in a public subnet. This was done to reduce cost so we would not need a NAT Gateway that runs $0.045 per hour and adds $0.045 per GB processed. Just ensure that the security group does not allow SSH access to improve security.
//TODO: Add lambda function to API Gateway HTTP trigger.
