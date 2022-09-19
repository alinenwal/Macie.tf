resource "aws_macie2_account" "this" {
  finding_publishing_frequency = "FIFTEEN_MINUTES" # ONE_HOUR, SIX_HOURS
  status = "ENABLED"
}

data "aws_caller_identity" "current" {}

resource "aws_macie2_organization_admin_account" "admin" {
  admin_account_id = data.aws_caller_identity.current.account_id
  #depends_on       = [aws_macie2_account.example]
}

# To auto-enable
resource "null_resource" "auto_enable" {
  provisioner "local-exec" {
    command = "aws macie2 update-organization-configuration --region us-east-1 --auto-enable --profile macie"
  }
  depends_on = [
    aws_macie2_account.this
  ]
}


# by default a detection job inherits all the managed data identifiers
# Macie uses certain criteria and techniques, including machine learning 
# and pattern matching, to detect sensitive data or anomalies. 
# These 'criteria and techniques' are typically referred to as managed data identifiers. 
# There's managed data identifiers for all kinds of categories, 
# think of financial information, personal health information, credentials, etc. 
# There's also a possibility to create your own data identifiers, 
# these are so called custom data identifiers. It consist of a regex to 
# perform a pattern match and a proximity rule to refine the result.

resource "aws_macie2_custom_data_identifier" "example" {
  name                   = "NAME OF CUSTOM DATA IDENTIFIER"
  regex                  = "[0-9]{3}-[0-9]{2}-[0-9]{4}"
  description            = "DESCRIPTION"
  maximum_match_distance = 10
  keywords               = ["keyword"]
  ignore_words           = ["ignore"]

  depends_on = [aws_macie2_account.this]
}

resource "aws_macie2_classification_job" "this" {
  job_type = "SCHEDULED"
  name     = "demo-macie-detection-job"
  job_status = "RUNNING"
  schedule_frequency {
    daily_schedule = "true"
  }
  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [
        "codepipeline-artifacts-storage-appcoe"]
    }
  }
  depends_on = [aws_macie2_account.this]
}

resource "aws_cloudwatch_event_rule" "this" {
  name        = "demo-event-rule"
  description = "Rule that captures AWS Macie findings"

  event_pattern = <<EOF
{
  "source": ["aws.macie"],
  "detail-type": ["Macie Finding"]
}
EOF
}

# resource "aws_cloudwatch_event_target" "this" {
#   rule = aws_cloudwatch_event_rule.this.name
#   arn  = aws_lambda_function.this.arn

#   depends_on = [aws_lambda_function.this]
# }