resource "vault_pki_secret_backend_cert" "this" {
  backend = "pki_intermediate"
  name    = "f5demo" # role name

  common_name           = var.common_name
  min_seconds_remaining = "1720000"
  auto_renew            = true
}

locals {
  trimPrivate   = trim(vault_pki_secret_backend_cert.this.private_key, "\n")
  trimCert      = trim(vault_pki_secret_backend_cert.this.certificate, "\n")
  trim_ca_chain = trim(vault_pki_secret_backend_cert.this.ca_chain, "\n")
}

resource "bigip_ssl_key" "key" {
  name      = "${var.app_prefix}${vault_pki_secret_backend_cert.this.expiration}.key"
  content   = local.trimPrivate
  partition = var.f5_partition

  lifecycle {
    create_before_destroy = true
  }
}

resource "bigip_ssl_certificate" "cert" {
  name      = "${var.app_prefix}${vault_pki_secret_backend_cert.this.expiration}.crt"
  content   = local.trimCert
  partition = var.f5_partition
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "bigip_ssl_certificate" "chain" {
  name      = "${var.app_prefix}${vault_pki_secret_backend_cert.this.expiration}cabundle.crt"
  content   = local.trim_ca_chain
  partition = var.f5_partition

  lifecycle {
    create_before_destroy = true
  }
}


resource "bigip_ltm_profile_client_ssl" "profile" {
  name          = "/${var.f5_partition}/clientssl_${var.app_prefix}"
  defaults_from = "/Common/clientssl"
  cert          = "/${var.f5_partition}/${bigip_ssl_certificate.cert.name}"
  key           = "/${var.f5_partition}/${bigip_ssl_key.key.name}"
  chain         = "/${var.f5_partition}/${bigip_ssl_certificate.chain.name}"
}

#LTM Pool and node attachment
resource "bigip_ltm_pool" "pool" {
  name                = "/Common/${var.app_prefix}_pool"
  load_balancing_mode = "round-robin"
  monitors            = ["/Common/http"]
  allow_snat          = "yes"
  allow_nat           = "yes"
}

resource "bigip_ltm_node" "node" {
  for_each = toset(var.node_list)
  name     = "/Common/${each.value}"
  address  = each.value
  monitor = "/Common/none"
}

resource "bigip_ltm_pool_attachment" "attach_node" {
  for_each = bigip_ltm_node.node
  pool     = bigip_ltm_pool.pool.name
  node     = "${bigip_ltm_node.node[each.key].name}:80"
}


# Create F5 virtual server
resource "bigip_ltm_virtual_server" "https" {
  name                       = "/Common/${var.app_prefix}_vs_https"
  destination                = var.vip_ip
  port                       = 443
  pool                       = bigip_ltm_pool.pool.name
  client_profiles            = [bigip_ltm_profile_client_ssl.profile.name]
  source_address_translation = "automap"
}


output "log_full_chain" {
  value     = local.trim_ca_chain
  sensitive = true
}

output "log_private_key" {
  value     = local.trimPrivate
  sensitive = true
}

output "log_cert" {
  value     = local.trimCert
  sensitive = true
}

### Validation Example

data "tls_certificate" "this" {
  url = "https://${var.common_name}"

  lifecycle {
    postcondition {
      condition     = self.certificates[0].serial_number == replace(vault_pki_secret_backend_cert.this.serial_number, ":", "")
      error_message = "Certificate serial numbers do not match for ${var.f5_partition}/${bigip_ssl_certificate.cert.name}"
    }
  }
} 