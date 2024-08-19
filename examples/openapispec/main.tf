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
  test_scripts = {for f in fileset(path.module, "tests*.js"): regex("tests(?P<path>.*)\\.js", f)["path"] => split("\n", file("${path.module}/${f}"))}
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
  test_scripts = local.test_scripts
  # Force a resort every time just in case
  sort_hash = timestamp()
}
