# Description
This project deploys the infrastructure needed for [the docker files](https://github.com/ddrmaster1000/amazon-scalable-discord-diffusion). An Architecture Diagram is shown below.
![Infrastructure Diagram](/files/discord-diffusion-diagram.png)

# AWS Article
Please use the [following link](https://aws.amazon.com/blogs/architecture/an-elastic-deployment-of-stable-diffusion-with-discord-on-aws/) for a walkthrough on how to use this project.

# Deployment
* Deploy in a region with a, b, and c availability zones. Such as us-west-2, us-east-1, us-east-2, etc.
* Ensure the region you have in the commandline if using the commandline is the region you will be deploying to. run ```aws configure``` to see the region. 
* After running a successful ```terraform apply```, it is required to start the CodeBuild run to create the docker image this project uses. 
* This project now uses Inferentia2 (inf.2xlarge)instances and **NO LONGER uses g4dn instances**. This increases the performance of inference and provides us to use specialized hardware designed for accelerated computing.
* This project implements Latent Consistency Models (LCM) with HuggingFace's Optimum library to perform inference: [HuggingFace LCM](https://huggingface.co/docs/optimum-neuron/tutorials/stable_diffusion#latent-consistency-models)
    * This shortens inference times from ~50+ seconds down to ~6 seconds for image request -> delivery to requestor. (Not including first time scale-up or backlog of requests)

# Commandline exports
The following variables must be exported to the commandline in order for ```terraform apply``` to work. See the variables.tf files if you need guidance on what these variables mean.<br>
```export TF_VAR_discord_bot_secret=''```<br>
```export TF_VAR_github_personal_access_token=''```<br>
```export TF_VAR_docker_password=''```<br>

# Future Improvements
1. This project does not take advantage of Spot instances. I would recommend adding Spot Instances and taking advantage of the savings they provide. Don't forget to check your Service Quotas before using Spot instances.
2. There is always something to improve for someone's use case. I do need some time to walk my dogs, pet my cats, and window shop RTX 4090s.