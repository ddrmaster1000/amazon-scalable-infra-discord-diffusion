output "discord_interactions_endpoint_url" {
  value = module.api_gw_lambda.discord_interactions_endpoint_url
}

output "ami" {
  value = module.ecs_cluster.ami
  sensitive = true
}