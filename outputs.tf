output "workspace_id" {
  value = var.create_workspace ? postman_workspace.Workspace[0].id : data.postman_workspace.Workspace[0].id
}
