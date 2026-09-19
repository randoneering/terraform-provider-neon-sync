# Manual `neon_trigger` testing

Drives the **locally-built** `terraform-provider-neon` against a real Neon
project to validate the `neon_trigger` resource end-to-end. The provider is
loaded via the `dev_overrides` mechanism so no registry fetch is needed.

This subdirectory is independent of `test/manual/` (which exercises
`neon_function`); you can run them side by side.

## Prerequisites

1. **Built and installed provider binary.** From the repo root:
   ```sh
   go build -o terraform-provider-neon_vdev .
   mkdir -p ~/.terraform.d/plugins/local/neondatabase/neon/dev/linux_amd64
   mv terraform-provider-neon_vdev ~/.terraform.d/plugins/local/neondatabase/neon/dev/linux_amd64/
   ```
   On macOS use `darwin_arm64` instead of `linux_amd64`.

2. **`~/.terraformrc`** with the dev override:
   ```hcl
   provider_installation {
     dev_overrides {
       "local/neondatabase/neon" = "/home/${USER}/.terraform.d/plugins/local/neondatabase/neon/dev/linux_amd64"
     }
     direct {}
   }
   ```
   Adjust the `dev_overrides` path if your home directory differs.

3. **`NEON_API_KEY`** set in the environment.

## Workflow

From this directory:

```sh
make plan      # shows what would be created
make apply     # creates the project, function, bucket, and both triggers
make show      # prints current state
make destroy   # tears everything down
make clean     # removes local .terraform/, state, plan files
```

`make init` (and therefore `make plan`/`make apply`) regenerates
`function.zip` from the inline template before running `terraform init`.

## What gets created

| Resource | Why |
|---|---|
| `neon_project.this` | Branch-scoped host for everything below |
| `neon_function.this` | Target for both triggers via `function_slug` |
| `neon_bucket.this` | Object source for the `storage_object_created` trigger |
| `neon_trigger.schedule` | Schedule trigger (cron-based invocation) |
| `neon_trigger.storage` | Storage trigger (fires on object upload) |

## Configurable variables

| Variable | Default | Override |
|---|---|---|
| `region_id` | `aws-us-east-2` | `TF_VAR_region_id` |
| `function_slug` | `tfmanualtrigger` | `TF_VAR_function_slug` |
| `schedule_trigger_name` | `every-five-minutes` | `TF_VAR_schedule_trigger_name` |
| `schedule_cron` | `*/5 * * * *` | `TF_VAR_schedule_cron` |
| `bucket_name` | `tfmanualtrigger-uploads` | `TF_VAR_bucket_name` |
| `storage_trigger_name` | `on-upload` | `TF_VAR_storage_trigger_name` |
| `storage_prefix` | `incoming/` | `TF_VAR_storage_prefix` |

## What to observe on `make apply`

- `terraform plan` should report a clean diff (no changes on subsequent runs)
- `terraform state list` should show all 5 resources
- The Neon console for the project should list one schedule trigger and one storage trigger under the default branch
- The schedule trigger fires every five minutes and posts to the function (logs visible in the Neon console)
- The storage trigger fires when an object lands under `incoming/` in the bucket

## Regenerating `function.zip` manually

```sh
cd test/manual-trigger
mkdir -p _bundle_tmp
echo "module.exports = async () => ({ statusCode: 200, body: 'ok' });" > _bundle_tmp/index.js
(cd _bundle_tmp && zip -q ../function.zip index.js)
rm -rf _bundle_tmp
```

## Known behaviour

- Triggers reference the function by `slug`. The server validates the slug exists at fire time, not at create time, so CRUD-only testing works without the function being "live" yet.
- `neon_trigger` is intentionally not importable. `terraform import` will return the diagnostic: `neon_trigger does not support import`.
- Out-of-band deletion (delete a trigger in the Neon console) is tolerated: the next `terraform plan` removes the resource from state with no diff.
