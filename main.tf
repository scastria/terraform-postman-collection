resource "postman_workspace" "Workspace" {
  count = var.create_workspace ? 1 : 0
  name = var.workspace_name
  type = var.workspace_type
}
resource "postman_collection" "Collection" {
  workspace_id = var.create_workspace ? postman_workspace.Workspace[0].id : data.postman_workspace.Workspace[0].id
  name = var.collection_name
  var {
    key = "url_base"
    value = var.url_base
  }
  dynamic "var" {
    for_each = var.collection_vars
    iterator = pvar
    content {
      key = pvar.key
      value = pvar.value
    }
  }
  pre_request_script = var.collection_pre_request_script
}
resource "postman_folder" "CategoryFolder" {
  for_each = toset(local.categories)
  collection_id = postman_collection.Collection.collection_id
  name = each.key
}
resource "postman_folder" "RequestFolder" {
  for_each = toset(local.folders)
  collection_id = postman_collection.Collection.collection_id
  parent_folder_id = postman_folder.CategoryFolder[split("--", each.key)[0]].folder_id
  name = split("--", each.key)[1]
}
resource "postman_folder" "ParentTestFolder" {
  collection_id = postman_collection.Collection.collection_id
  name = var.automated_tests_folder
  post_response_script = lookup(var.test_scripts, "", [])
}
resource "postman_folder" "TestStatusFolder" {
  for_each = var.tests
  collection_id = postman_collection.Collection.collection_id
  parent_folder_id = postman_folder.ParentTestFolder.folder_id
  name = each.key
  post_response_script = lookup(var.test_scripts, "--${split("--", each.key)[0]}", [""])
}
resource "postman_folder" "TestStatusGroupFolder" {
  for_each = toset(local.test_status_group_folders)
  collection_id = postman_collection.Collection.collection_id
  parent_folder_id = postman_folder.TestStatusFolder[split("--", each.key)[0]].folder_id
  name = split("--", each.key)[1]
  post_response_script = lookup(var.test_scripts, "--${split("--", each.key)[0]}--${split("--", each.key)[1]}", [""])
}
resource "postman_folder" "TestRequestFolder" {
  for_each = toset(local.test_request_folders)
  collection_id = postman_collection.Collection.collection_id
  parent_folder_id = postman_folder.TestStatusGroupFolder["${split("--", each.key)[0]}--${split("--", each.key)[1]}"].folder_id
  name = split("--", each.key)[2]
  post_response_script = lookup(var.test_scripts, "--${split("--", each.key)[0]}--${split("--", each.key)[1]}${replace(split("--", each.key)[2], "/", "--")}", [""])
}
resource "postman_collection_sort" "CollectionSort" {
  collection_id = postman_collection.Collection.collection_id
  case_sensitive = true
  hash = var.sort_hash
  depends_on = [
    postman_folder.CategoryFolder,
    postman_folder.RequestFolder,
    postman_request.Request,
    postman_folder.ParentTestFolder,
    postman_folder.TestStatusFolder,
    postman_folder.TestStatusGroupFolder,
    postman_folder.TestRequestFolder,
    postman_request.TestRequest
  ]
}
resource "postman_request" "Request" {
  for_each = toset(local.requests)
  collection_id = postman_collection.Collection.collection_id
  folder_id = postman_folder.RequestFolder["${split("--", each.key)[0]}--${split("--", each.key)[1]}"].folder_id
  name = split("--", each.key)[2]
  method = upper(split("--", each.key)[2])
  description = "${lookup(local.oas["paths"][split("--", each.key)[1]][split("--", each.key)[2]], "summary", "")}\n\n${lookup(local.oas["paths"][split("--", each.key)[1]][split("--", each.key)[2]], "description", "")}"
  base_url = "{{url_base}}${split("--", each.key)[1]}"
  body = lookup(lookup(lookup(var.default_param_values, split("--", each.key)[1], {}), split("--", each.key)[2], {}), "body", null) == null ? null : jsonencode(lookup(lookup(lookup(var.default_param_values, split("--", each.key)[1], {}), split("--", each.key)[2], {}), "body", {}))
  dynamic "query_param" {
    for_each = local.query_params[each.key]
    content {
      key = query_param.value["name"]
      value = lookup(lookup(lookup(lookup(var.default_param_values, split("--", each.key)[1], {}), split("--", each.key)[2], {}), "query_params", {}), query_param.value["name"], "")
      enabled = lookup(query_param.value, "required", false)
    }
  }
  dynamic "header" {
    for_each = lookup(lookup(lookup(var.default_param_values, split("--", each.key)[1], {}), split("--", each.key)[2], {}), "headers", {})
    content {
      key = header.key
      value = header.value
      enabled = true
    }
  }
}
resource "postman_request" "TestRequest" {
  for_each = toset(local.test_requests)
  collection_id = postman_collection.Collection.collection_id
  folder_id = postman_folder.TestRequestFolder["${split("--", each.key)[0]}--${split("--", each.key)[1]}--${split("--", each.key)[2]}"].folder_id
  name = "${split("--", each.key)[3]}-${split("--", each.key)[4]}"
  method = upper(split("--", each.key)[3])
  base_url = "{{url_base}}${split("--", each.key)[2]}"
  body = lookup(var.tests[split("--", each.key)[0]][split("--", each.key)[1]][split("--", each.key)[2]][split("--", each.key)[3]][split("--", each.key)[4]], "body", null) == null ? null : jsonencode(lookup(var.tests[split("--", each.key)[0]][split("--", each.key)[1]][split("--", each.key)[2]][split("--", each.key)[3]][split("--", each.key)[4]], "body", null))
  dynamic "query_param" {
    for_each = toset(flatten([for qp, qpv in lookup(var.tests[split("--", each.key)[0]][split("--", each.key)[1]][split("--", each.key)[2]][split("--", each.key)[3]][split("--", each.key)[4]], "query_params", {}): [
      for i, qv in try([tostring(qpv)], tolist(qpv)): "${qp}--${i}"
    ]]))
    content {
      key = split("--", query_param.key)[0]
      value = try(var.tests[split("--", each.key)[0]][split("--", each.key)[1]][split("--", each.key)[2]][split("--", each.key)[3]][split("--", each.key)[4]]["query_params"][split("--", query_param.key)[0]][split("--", query_param.key)[1]], var.tests[split("--", each.key)[0]][split("--", each.key)[1]][split("--", each.key)[2]][split("--", each.key)[3]][split("--", each.key)[4]]["query_params"][split("--", query_param.key)[0]])
      enabled = true
    }
  }
  dynamic "header" {
    for_each = lookup(var.tests[split("--", each.key)[0]][split("--", each.key)[1]][split("--", each.key)[2]][split("--", each.key)[3]][split("--", each.key)[4]], "headers", {})
    content {
      key = header.key
      value = header.value
      enabled = true
    }
  }
  post_response_script = lookup(var.test_scripts, "--${split("--", each.key)[0]}--${split("--", each.key)[1]}${replace(split("--", each.key)[2], "/", "--")}--${split("--", each.key)[3]}", [""])
}
