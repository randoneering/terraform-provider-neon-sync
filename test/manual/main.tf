terraform {
  required_providers {
    neon = {
      source = "local/neondatabase/neon"
    }
  }
}

provider "neon" {
  # api_key is read from the NEON_API_KEY env var by the provider.
}

variable "org_id" {
  description = "Neon organization ID. Override with TF_VAR_org_id or -var=org_id=..."
  type        = string
  default     = "org-twilight-cake-44366159"
}

variable "region_id" {
  type    = string
  default = "aws-us-east-2"
}

variable "function_slug" {
  type    = string
  default = "tfmanual"
}

variable "function_name" {
  type    = string
  default = "tfmanual"
}

resource "neon_project" "this" {
  org_id    = var.org_id
  name      = "tf-manual-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
  region_id = var.region_id
}

resource "neon_function" "this" {
  project_id    = neon_project.this.id
  branch_id     = neon_project.this.default_branch_id
  slug          = var.function_slug
  runtime       = "nodejs24"
  name          = var.function_name
  zip_file_path = "${path.module}/function.zip"

  environment_variables = {
    LOG_LEVEL = "info"
  }
}

output "project_id" {
  value = neon_project.this.id
}

output "function_id" {
  value = neon_function.this.id
}

output "function_invocation_url" {
  value = neon_function.this.invocation_url
}
