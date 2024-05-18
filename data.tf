data "http" "openapi_spec" {
  url = var.openapi_url
}
data "postman_workspace" "Workspace" {
  count = var.create_workspace ? 0 : 1
  name = var.workspace_name
  type = var.workspace_type
}
