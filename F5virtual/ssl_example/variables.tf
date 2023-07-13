variable "auto_renew" {
  type = bool
  description = "vault pki auto renew"
  default = true
}

variable "pki_intermediate_path" {
  type        = string
  description = "pki intermediate path"
  default     = "pki_intermediate"
}

variable "pki_role" {
  type        = string
  description = "pki role name"
  default     = "f5demo"
}

variable "common_name" {
  type        = string
  description = "certificate common name"
  default     = "dev.f5demo.com"
}
