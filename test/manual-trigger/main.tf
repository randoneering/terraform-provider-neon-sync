terraform {
  required_providers {
    neon = {
      source = "neondatabase/neon"
    }
  }
}

provider "neon" {
  # api_key is read from the NEON_API_KEY env var by the provider.
}

variable "region_id" {
  description = "Neon region for the test project."
  type        = string
  default     = "aws-us-east-2"
}

variable "org_id" {
  description = "Neon organization ID. Override with TF_VAR_org_id or -var=org_id=..."
  type        = string
  default     = "org-twilight-cake-44366159"
}

variable "function_slug" {
  description = "Branch-local Function slug referenced by both triggers."
  type        = string
  default     = "tfmanualtrigger"
}

variable "schedule_trigger_name" {
  type    = string
  default = "every-five-minutes"
}

variable "schedule_cron" {
  description = "Numeric five-field cron expression in UTC."
  type        = string
  default     = "*/5 * * * *"
}

variable "bucket_name" {
  type    = string
  default = "tfmanualtrigger-uploads"
}

variable "storage_trigger_name" {
  type    = string
  default = "on-upload"
}

variable "storage_prefix" {
  description = "Object-key prefix matched by the storage_object_created trigger."
  type        = string
  default     = "incoming/"
}

resource "neon_project" "this" {
  org_id    = var.org_id
  name      = "tf-manual-trigger-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
  region_id = var.region_id
}

resource "neon_function" "this" {
  project_id    = neon_project.this.id
  branch_id     = neon_project.this.default_branch_id
  slug          = var.function_slug
  runtime       = "nodejs24"
  name          = var.function_slug
  zip_file_path = "${path.module}/function.zip"
}

resource "neon_bucket" "this" {
  project_id = neon_project.this.id
  branch_id  = neon_project.this.default_branch_id
  name       = var.bucket_name
}

resource "neon_trigger" "schedule" {
  project_id    = neon_project.this.id
  branch_id     = neon_project.this.default_branch_id
  name          = var.schedule_trigger_name
  type          = "schedule"
  function_slug = neon_function.this.slug
  cron          = var.schedule_cron
}

resource "neon_trigger" "storage" {
  project_id    = neon_project.this.id
  branch_id     = neon_project.this.default_branch_id
  name          = var.storage_trigger_name
  type          = "storage_object_created"
  function_slug = neon_function.this.slug
  bucket_name   = neon_bucket.this.name
  prefix        = var.storage_prefix
  depends_on    = [neon_bucket.this]
}

output "project_id" {
  value = neon_project.this.id
}

output "function_id" {
  value = neon_function.this.id
}

output "schedule_trigger_id" {
  value = neon_trigger.schedule.trigger_id
}

output "storage_trigger_id" {
  value = neon_trigger.storage.trigger_id
}

output "function_invocation_url" {
  description = "Triggers invoke this function via `function_slug`."
  value       = neon_function.this.invocation_url
}
