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
    if(loc.share && local.share_cross_account) || loc.principal != null
  }

  principal                     = try(each.value.principal, data.aws_caller_identity.destination.account_id)
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
    if local.share_cross_account || loc.principal != null
  }

  principal                     = try(each.value.principal, data.aws_caller_identity.destination.account_id)
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
    if(local.share_cross_account && db.share_all_tables) || loc.principal != null
  }

  principal                     = try(each.value.principal, data.aws_caller_identity.destination.account_id)
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
    for tbl in var.tables_to_share : tbl.source_table => tbl
    if local.share_cross_account || loc.principal != null
  }

  principal                     = try(each.value.principal, data.aws_caller_identity.destination.account_id)
  permissions                   = each.value.permissions
  permissions_with_grant_option = each.value.permissions


  table {
    database_name = each.value.source_database
    name          = each.value.source_table
  }

  depends_on = [aws_lakeformation_permissions.database_share]
}

resource "aws_glue_catalog_database" "destination_database" {
  provider = aws.destination
  for_each = {
    for tbl in var.tables_to_share : tbl.source_table => tbl if tbl.destination_database.create_database
  }

  name = each.value.destination_database.database_name
}

resource "aws_glue_catalog_database" "destination_account_database_resource_link" {
  provider = aws.destination
  for_each = {
    for db in var.databases_to_share : db.name => db
  }

  name = "${each.key}_resource_link"

  target_database {
    catalog_id    = data.aws_caller_identity.source.account_id
    database_name = each.key
    region        = data.aws_region.source.name
  }

  depends_on = [aws_lakeformation_permissions.table_share_all, aws_lakeformation_permissions.table_share_selected]
  lifecycle {
    ignore_changes = [
      # Change to description  require alter permissions which aren't typicically granted or needed
      description
    ]
  }
}

resource "aws_glue_catalog_table" "destination_account_table_resource_link" {
  provider = aws.destination
  for_each = {
    for tbl in var.tables_to_share : tbl.source_table => tbl
  }

  name          = try(each.value.resource_link_name, "${each.key}_resource_link") # what to name the resoruce link in the destintion account
  database_name = each.value.destination_database.database_name                   # what database to place the resource link into
  target_table {
    name          = each.key # the shared database
    catalog_id    = data.aws_caller_identity.source.account_id
    database_name = each.value.source_database # shared database
    region        = data.aws_region.source.name
  }

  lifecycle {
    ignore_changes = [
      # Change to description  require alter permissions which aren't typicically granted or needed
      description
    ]
  }

  depends_on = [aws_lakeformation_permissions.table_share_all, aws_lakeformation_permissions.table_share_selected]
}
