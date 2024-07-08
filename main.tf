resource "aws_lakeformation_resource" "data_location" {
  provider = aws.source
  for_each = {
    for idx, loc in var.data_locations : loc.data_location => loc
    if loc.register == true
  }

  arn                     = each.value.data_location
  use_service_linked_role = true
  hybrid_access_enabled   = try(each.value.hybrid_mode, false) # unless explicitly specified, data locations will be managed exclusively via Lake Formation
  # depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "data_location_share" {
  provider = aws.source
  for_each = {
    for idx, loc in var.data_locations : loc.data_location => loc
    if loc.share == true
  }

  principal                     = data.aws_caller_identity.target.account_id
  permissions                   = ["DATA_LOCATION_ACCESS"]
  permissions_with_grant_option = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = each.value.data_location
  }
  depends_on = [aws_lakeformation_resource.data_location]
}

resource "aws_lakeformation_permissions" "database_share" {
  provider = aws.source
  for_each = {
    for db in var.databases_to_share : db.name => db
  }

  principal                     = data.aws_caller_identity.target.account_id
  permissions                   = each.value.permissions
  permissions_with_grant_option = each.value.permissions

  database {
    name = each.value.name
  }

  depends_on = [aws_lakeformation_permissions.data_location_share]
}

resource "aws_lakeformation_permissions" "table_share" {
  provider = aws.source
  for_each = {
    for db in var.databases_to_share : db.name => db
  }

  principal                     = data.aws_caller_identity.target.account_id
  permissions                   = ["SELECT"]
  permissions_with_grant_option = ["SELECT"]


  table {
    database_name = each.value.name
    wildcard      = true
  }

  depends_on = [aws_lakeformation_permissions.database_share]
}

resource "aws_glue_catalog_database" "target_account_resource_link" {
  provider = aws.target
  for_each = {
    for db in var.databases_to_share : db.name => db
  }

  name = "${each.key}_resource_link"

  target_database {
    catalog_id    = data.aws_caller_identity.current.account_id
    database_name = each.key
    region        = data.aws_region.current.name
  }

  depends_on = [aws_lakeformation_permissions.table_share]
}