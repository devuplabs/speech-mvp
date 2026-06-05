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

variable "region" {
  description = "Region used to pin Secret Manager replicas for the Firebase web client config secrets (matches the rest of the stack — europe-west2 on UK)."
  type        = string
  default     = "europe-west2"
}

variable "name_prefix" {
  description = "Prefix for Secret Manager IDs (e.g. 'sona' → 'sona-firebase-web-api-key')."
  type        = string
  default     = "sona"
}

variable "publish_web_config_secrets" {
  description = "When true, the 5 Firebase Web client-config values are also written to Secret Manager so Cloud Build can inject them as --dart-define at build time. The Firebase Web API key is public client config per Firebase docs — Secret Manager is used here for hygiene + central rotation, NOT because the value is secret."
  type        = bool
  default     = true
}

variable "cloudbuild_secret_accessor_emails" {
  description = "Service-account emails granted roles/secretmanager.secretAccessor on the 5 Firebase config secrets (typically the Cloud Build SA that runs sona-web-dev-deploy). Empty list disables the IAM grant (use when publish_web_config_secrets = false)."
  type        = list(string)
  default     = []
}
