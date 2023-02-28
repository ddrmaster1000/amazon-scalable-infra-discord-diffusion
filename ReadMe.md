# Description
This project deploys the infrastructure needed for [TODO-MY-GITHUB-HERE](). An Architecture Diagram is shown below.
![Infrastructure Diagram](/files/discord-diffusion-diagram.png)

# AWS Article
Please use the [following link]() for a walkthrough on how to use this project.

# Commandline exports
```export TF_VAR_discord_bot_secret=''```<br>
```export TF_VAR_github_personal_access_token=''```<br>
```export TF_VAR_docker_password=''```<br>

# Future Improvements
1. This project does not take advantage of Spot instances. I would recommend adding Spot Instances and taking advantage of the savings they provide. Don't forget to check your Service Quotas before using Spot instances for the 'G' Instance class.
2. There is always something to improve for someone's use case. I do need some time to walk my dogs, pet my cats, and window shop RTX 4090s.