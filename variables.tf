variable "data_locations" {
  description = "List of data locations (currently S3 buckets) to share with destination account"
  type = list(object({
    data_location = string
    hybrid_mode   = optional(bool, null)
    register      = optional(bool, null)
    share         = optional(bool, true)
  }))
  default = []

  validation {
    condition = alltrue([
      for v in var.data_locations : (
        (v.hybrid_mode == null || v.register == true) &&
        (v.share != false || v.register == true)
      )
    ])
    error_message = "For each data location: If 'hybrid_mode' is not null or 'share' is false, 'register' must be true."
  }
}

# variable "lake_formation_settings" {
#   description = "Map of Lake Formation settings to configure as part of the sharing"
#   type = object({
#     data_lake_admins                         = optional(list(string),[]) # role running the terraform in will be added as an admin automatically
#     iam_manage_new_databases = optional(bool, false)
#     iam_manage_new_tables    = optional(bool, false)
#     trusted_resource_owners                  = optional(list(string))
#   })
#   default = {}
# }

variable "databases_to_share" {
  description = "List of databases to share with destination account"
  type = list(object({
    name                         = string
    permissions                  = optional(list(string), ["DESCRIBE"])
    share_all_tables             = optional(bool, true),
    share_all_tables_permissions = optional(list(string), ["SELECT", "DESCRIBE"])
  }))
  default = []
}

variable "tables_to_share" {
  description = <<EOF
  List of tables to share with destination account.
  If the user is NOT creating a new destination_database,
  (i.e. providing an existing database),
  the database must exist or execution will fail silently.
  EOF
  type = list(object({
    source_database          = string
    resource_link_table_name = optional(string, null)
    destination_database = object({
      database_name   = string
      create_database = bool
    })
    source_table = string
    permissions  = optional(list(string), ["SELECT", "DESCRIBE"])
  }))
  default = []
}
