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
    if loc.share && local.share_cross_account #no need to share data location if it's in the same account
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
    if local.share_cross_account #no need to share database if it's in the same account
  }

  principal                     = data.aws_caller_identity.target.account_id
  permissions                   = each.value.permissions
  permissions_with_grant_option = each.value.permissions

  database {
    name = each.value.name
  }

  depends_on = [aws_lakeformation_permissions.data_location_share]
}

resource "aws_lakeformation_permissions" "table_share_all" {
  provider = aws.source
  for_each = {
    for db in var.databases_to_share : db.name => db
    if local.share_cross_account && db.share_all_tables #no need to share table if it's in the same account
  }

  principal                     = data.aws_caller_identity.target.account_id
  permissions                   = each.value.share_all_tables_permissions
  permissions_with_grant_option = each.value.share_all_tables_permissions


  table {
    database_name = each.value.name
    wildcard      = true
  }

  depends_on = [aws_lakeformation_permissions.database_share]
}


resource "aws_lakeformation_permissions" "table_share_selected" {
  provider = aws.source
  for_each = {
    for tbl in var.tables_to_share : tbl.name => tbl
    if local.share_cross_account #no need to share table if it's in the same account
  }

  principal                     = data.aws_caller_identity.target.account_id
  permissions                   = each.value.permissions
  permissions_with_grant_option = each.value.permissions


  table {
    database_name = each.value.database
    name          = each.value.name
  }

  depends_on = [aws_lakeformation_permissions.database_share]
}

resource "aws_glue_catalog_database" "database_target" {
  provider = aws.target
  for_each = {
    for db in var.databases_to_share : db.name => db
  }

  name = each.key
}
resource "aws_glue_catalog_database" "target_account_database_resource_link" {
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

  depends_on = [aws_lakeformation_permissions.table_share_all, aws_lakeformation_permissions.table_share_selected]
}


resource "aws_glue_catalog_table" "target_account_table_resource_link" {
  provider = aws.target
  for_each = {
    for tbl in var.tables_to_share : tbl.name => tbl
  }

  name          = try(each.value.target_tbl, "${each.key}_resource_link")
  database_name = each.value.target_db

  target_table {
    name          = each.key
    catalog_id    = data.aws_caller_identity.current.account_id
    database_name = each.value.database
    region        = data.aws_region.current.name
  }

  depends_on = [aws_lakeformation_permissions.table_share_all, aws_lakeformation_permissions.table_share_selected]
}
