# module "sqs" {
#   source  = "terraform-aws-modules/sqs/aws"
#   version = "3.4.0"
# }

# module "iam" {
#   source  = "terraform-aws-modules/iam/aws"
#   version = "5.5.0"
# }

# module "lambda" {
#   source  = "terraform-aws-modules/lambda/aws"
#   version = "4.0.2"
# }

# module "api_gateway" {
#   source = "terraform-aws-modules/apigateway-v2/aws"
#   version = "2.2.0"
#   create = false # to disable all resources

#   create_api_gateway               = false  # to control creation of API Gateway
#   create_api_domain_name           = false  # to control creation of API Gateway Domain Name
#   create_default_stage             = false  # to control creation of "$default" stage
#   create_default_stage_api_mapping = false  # to control creation of "$default" stage and API mapping
#   create_routes_and_integrations   = false  # to control creation of routes and integrations
#   create_vpc_link                  = false  # to control creation of VPC link

#   # ... omitted
# }