pid_file = "./pidfile"

vault {
   address = "https://hcp-vault-demo-public-vault-457f3ef0.5ef008f8.z1.hashicorp.cloud:8200"
}

auto_auth {
   method "approle" {
       mount_path = "auth/approle"
       config = {
           role_id_file_path = "roleID"
           secret_id_file_path = "secretID"
           remove_secret_id_file_after_reading = false
       }
   }

   sink "file" {
       config = {
           path = "approleToken"
       }
   }
}

template {
  source      = "/home/ubuntu/vault-f5-pki-rotation-splunk/vault_agent_config/certs.ctmpl"
  destination = "./certs.json"
  command = "bash f5-magic.sh"
}

template {
    source = "/home/ubuntu/vault-f5-pki-rotation-splunk/vault_agent_config/certmanagement.tmpl"
    destination = "./certmanagement.json"
}
