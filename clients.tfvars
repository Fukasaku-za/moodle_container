//*******************************************
// NON-SECRET tenant config — safe to commit.
// Secrets go in TF_VAR_client_secrets (see below), never here.
//*******************************************

saas_domain = "learngrc.xyz"

new_clients = {
  # client identifier = "macadonia", served at hero.learngrc.xyz
  macadonia = {
    subdomain   = "hero"
    image       = "bitnami/moodle:latest" # switch to ECR URI after first push
    site_name   = "Macadonia"
    admin_user  = "admin"
    admin_email = "admin@hero.learngrc.xyz"
    priority    = 100
  }

  # add the next client by appending another block, e.g.:
  # nova = {
  #   subdomain   = "nova"
  #   image       = "bitnami/moodle:latest"
  #   site_name   = "Nova Learning"
  #   admin_user  = "admin"
  #   admin_email = "admin@nova.learngrc.xyz"
  #   priority    = 110
  # }
}

//*******************************************
// Secrets — DO NOT put them above. Export before apply:
//
//   export TF_VAR_client_secrets='{
//     "macadonia": {
//       "admin_password": "REPLACE_ME",
//       "db_password":    "REPLACE_ME"
//     }
//   }'
//
// (every key in new_clients needs a matching entry here)
//*******************************************
