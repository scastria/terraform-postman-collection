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

module "openapispec" {
  source = "../.."
  workspace_name = "Module"
  collection_name = "Collection"
  openapi_url = "https://httpbin.org/spec.json"
  url_base = "https://httpbin.org"
  default_param_values = yamldecode(file("${path.module}/default_params.yml"))
  test_script = split("\n", file("${path.module}/tests.js"))
  tests = yamldecode(file("${path.module}/tests.yml"))
  # Force a resort every time just in case
  sort_hash = timestamp()
}
