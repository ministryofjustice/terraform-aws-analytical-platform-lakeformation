locals {
  share_cross_account = data.aws_caller_identity.current.account_id != data.aws_caller_identity.target.account_id
}
