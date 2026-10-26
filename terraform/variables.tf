variable "region" {
  description = "OCI home region, for example af-casablanca-1."
  type        = string
}

variable "tenancy_ocid" {
  description = "OCID of your tenancy (parent of the kenshoo compartment)."
  type        = string
}

variable "oci_config_profile" {
  type    = string
  default = "DEFAULT"
}

variable "compartment_name" {
  type    = string
  default = "kenshoo"
}

variable "admin_cidr" {
  description = "Your public IP as a CIDR, e.g. 203.0.113.7/32. Only this range reaches SSH and the Kubernetes API."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a valid CIDR and must not be 0.0.0.0/0."
  }
}

variable "ssh_public_key" {
  description = "Contents of the SSH public key allowed to log in."
  type        = string
}

variable "create_instance" {
  description = "Phase switch: false creates only the compartment and network, true also creates the instance."
  type        = bool
  default     = false
}

variable "vcn_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "instance_ocpus" {
  type    = number
  default = 2
}

variable "instance_memory_gb" {
  type    = number
  default = 12
}

variable "boot_volume_gb" {
  type    = number
  default = 50
}

variable "availability_domain_index" {
  type    = number
  default = 0
}
