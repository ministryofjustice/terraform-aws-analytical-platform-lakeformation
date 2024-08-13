
data "aws_caller_identity" "current" {
  provider = aws.source
}

data "aws_region" "current" {
  provider = aws.source
}

data "aws_caller_identity" "destination" {
  provider = aws.destination
}

# data "aws_iam_session_context" "target" {
#   provider = aws.target
#   arn      = data.aws_caller_identity.target.arn
# }
