locals {
  oas = jsondecode(data.http.openapi_spec.response_body)
  paths = [for p, pv in local.oas["paths"] : p if (length(var.path_prefix_include_filter) == 0) || (anytrue([for prefix in var.path_prefix_include_filter: startswith(p, prefix)]))]
  # category
  categories = distinct(flatten([for p in local.paths : [
    for m, mv in local.oas["paths"][p] : ((length(lookup(mv, "tags", [])) > 0) ? mv["tags"][0] : var.uncategorized_api_folder)
  ]]))
  # category--path
  folders = distinct(flatten([for p in local.paths : [
    for m, mv in local.oas["paths"][p] : ((length(lookup(mv, "tags", [])) > 0) ? "${mv["tags"][0]}--${p}" : "${var.uncategorized_api_folder}--${p}")
  ]]))
  # category--path--method
  requests = flatten([for f in local.folders : [
    for m, mv in local.oas["paths"][split("--", f)[1]] : "${f}--${m}" if (length(var.method_exclude_filter) == 0) || (!anytrue([for method in var.method_exclude_filter: (lower(m) == method)]))
  ]])
  query_params = {for r in local.requests : r => [
    for q in lookup(local.oas["paths"][split("--", r)[1]][split("--", r)[2]], "parameters", []) : q if q["in"] == "query"
  ]}
  test_folders = [for p, pv in var.tests: p if (length(var.path_prefix_include_filter) == 0) || (anytrue([for prefix in var.path_prefix_include_filter: startswith(p, prefix)]))]
  # path--method--index
  test_requests = flatten([for p in local.test_folders: [
    for m, mv in var.tests[p]: [
      for i, t in mv: "${p}--${m}--${i}"
  ]]])
}
