resource "aws_dynamodb_table" "user_queries" {
  name         = "${var.project_id}-userqueries"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "interactionId"
  #   range_key      = "SubmitTime"

  attribute {
    name = "interactionId"
    type = "S"
  }

  #   attribute {
  #     name = "SubmitTime"
  #     type = "S"
  #   }

  #   ttl {
  #     attribute_name = "TimeToExist"
  #     enabled        = false
  #   }

  #   global_secondary_index {
  #     name               = "GameTitleIndex"
  #     hash_key           = "GameTitle"
  #     range_key          = "TopScore"
  #     projection_type    = "INCLUDE"
  #     non_key_attributes = ["UserId"]
  #   }

  tags = {
    Name = "${var.project_id}-userqueries"
  }
}