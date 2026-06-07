//*******************************************
// NON-SECRET tenant config — safe to commit.
// Secrets go in TF_VAR_client_secrets (see below), never here.
//*******************************************

saas_domain = "learngrc.xyz"


# client identifier = "macadonia", served at hero.learngrc.xyz
new_clients = {
  macadonia = {
    subdomain   = "hero"
    image       = "627031162962.dkr.ecr.af-south-1.amazonaws.com/oneconnect/moodle:macadonia-latest"
    site_name   = "Macadonia"
    admin_user  = "admin"
    admin_email = "lwanda@untu2clud.co.za"
    priority    = 100
  }
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
   export TF_VAR_client_secrets='{
     "macadonia": {
       "admin_password": "Pa$$w0rd2026!",
       "db_password":    "Pa$$w0rd2026!"
     }
   }'
//
// (every key in new_clients needs a matching entry here)
//*******************************************
