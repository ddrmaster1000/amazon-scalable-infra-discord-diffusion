# Setup Instructions
Login to the discord developers website. 
Create a Discord bot. - Look online to do this.
Add the app to a server - Look online to do this.  
Copy Application ID and Public key for the terraform apply
Best practice to store secret by commandline at a minimum. Never has it as plain text! ```export TF_VAR_discord_application_secret='YOURSECRETHERE'```

# Architecture
Note that the ECS machines are in a public subnet. This was done to reduce cost so we would not need a NAT Gateway that runs $0.045 per hour and adds $0.045 per GB processed. Just ensure that the security group does not allow SSH access to improve security.
//TODO: Add lambda function to API Gateway HTTP trigger.
