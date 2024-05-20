terraform {
  required_version = "~> 1.5"
  required_providers {
    postman = {
      source = "scastria/postman"
      version = "~> 0.1"
    }
  }
}

provider "postman" {}

locals {
  test_request_test_script_paths = toset([for f in fileset(path.module, "tests--*.js"): regex("tests(?P<path>.*)--(?P<method>.*)\\.js", f)["path"]])
  test_request_test_scripts = {for p in local.test_request_test_script_paths: replace(p, "--", "/") => {
    for f in fileset(path.module, "tests${p}--*.js") : regex("tests(?P<path>.*)--(?P<method>.*)\\.js", f)["method"] => split("\n", file("${path.module}/${f}"))
  }}
}

module "openapispec" {
  source = "../.."
  workspace_name = "Module"
  collection_name = "Collection"
  openapi_url = "https://httpbin.org/spec.json"
  url_base = "https://httpbin.org"
  default_param_values = yamldecode(file("${path.module}/default_params.yml"))
  test_script = split("\n", file("${path.module}/tests.js"))
  tests = yamldecode(file("${path.module}/tests.yml"))
  test_request_test_scripts = local.test_request_test_scripts
  # Force a resort every time just in case
  sort_hash = timestamp()
}
