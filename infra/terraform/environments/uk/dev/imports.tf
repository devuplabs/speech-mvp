# Adopt sona-web-dev if it was created outside Terraform (e.g. one-off Cloud Build).
# Ignored once the resource is already in state.
import {
  to = module.stack.module.cloud_run.google_cloud_run_v2_service.web[0]
  id = "projects/project-a625d19b-de99-48e9-9a9/locations/europe-west2/services/sona-web-dev"
}

import {
  to = module.stack.module.cloud_run.google_cloud_run_v2_service_iam_member.web_public[0]
  id = "projects/project-a625d19b-de99-48e9-9a9/locations/europe-west2/services/sona-web-dev roles/run.invoker allUsers"
}
