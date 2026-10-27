# Windows VM administrator password
variable "admin_password" {
  description = "Administrator password for Dev-win01"
  type        = string
  sensitive   = true
}