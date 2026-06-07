//*******************************************
// MULTI-TENANT VARIABLES
// (add these; do NOT remove your existing variables)
//*******************************************

variable "saas_domain" {
  type        = string
  description = "Root SaaS domain. Clients are <subdomain>.<saas_domain>"
  default     = "learngrc.xyz"
}

// Non-secret tenant config. Add a block per new client.
variable "new_clients" {
  description = "New SaaS tenants. oneconnect stays in its own files and is NOT listed here."
  type = map(object({
    subdomain     = string
    image         = string // ECR URI, or bitnami/moodle:latest to bootstrap
    site_name     = string
    admin_user    = string
    admin_email   = string
    priority      = number // unique ALB listener-rule priority (1-50000)
    db_name       = optional(string, "moodle")
    db_username   = optional(string, "moodle_user")
    cpu           = optional(number, 1024)
    memory        = optional(number, 2048)
    desired_count = optional(number, 1)
  }))
  default = {}
}

// Secrets kept OUT of the map above and OUT of git.
// Provide via environment, e.g.:
//   export TF_VAR_client_secrets='{"macadonia":{"admin_password":"...","db_password":"..."}}'
// or a tfvars file you never commit.
variable "client_secrets" {
  description = "Per-tenant secrets keyed by client name"
  type = map(object({
    admin_password = string
    db_password    = string
  }))
  sensitive = true
  default   = {}
}
