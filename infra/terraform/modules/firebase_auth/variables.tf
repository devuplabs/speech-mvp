variable "project_id" {
  description = "GCP project id for this environment."
  type        = string
}

variable "runtime_service_account_email" {
  description = "Cloud Run runtime SA — granted firebaseauth.admin so the API can mint invite links / manage users (Auth·05)."
  type        = string
}

variable "authorized_domains" {
  description = "Domains allowed to complete sign-in / email-link flows (Cloud Run web URL, custom domains, localhost for dev)."
  type        = list(string)
  default     = ["localhost"]
}

variable "web_app_display_name" {
  description = "Display name for the registered Firebase Web App (client config for the Flutter app)."
  type        = string
  default     = "Sona Web"
}
