
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_caller_identity" "target" {
  provider = aws.target
}

data "aws_region" "target" {
  provider = aws.target
}

data "aws_iam_session_context" "target" {
  provider = aws.target
  arn      = data.aws_caller_identity.target.arn
}