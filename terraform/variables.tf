variable "admin_email" {
  description = "Email of the initial admin user in Cognito"
  type        = string
}

variable "admin_password" {
  description = "Password for the initial admin user in Cognito"
  type        = string
  sensitive   = true
}
