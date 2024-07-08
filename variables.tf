variable "glue_catalogue" {

  type    = string
  default = null
}

variable "data_locations" {
  description = "List of data locations (currently S3 buckets) to share with target account"
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
  description = "List of databases to share with target account"
  type = list(object({
    name        = string
    target_db   = string
    permissions = optional(list(string), ["DESCRIBE", "CREATE_TABLE"])
  }))
  default = []
}

variable "tables_to_share" {
  description = "List of tables to share with target account"
  type = list(object({
    database    = string
    name        = string
    target_db   = string
    target_tbl  = string
    permissions = optional(list(string), ["SELECT", "INSERT"])
    column_permissions = optional(list(object({
      name        = string
      columns     = list(string)
      permissions = list(string)
    })), [])
  }))
  default = []
}