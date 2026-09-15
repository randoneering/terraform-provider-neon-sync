# Manual terraform CLI testing

Drives the **locally-built** `terraform-provider-neon` against a real Neon
project to validate end-to-end behavior. The provider is loaded via the
`dev_overrides` mechanism so no registry fetch is needed.

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

4. **`ORG_ID`** — default is hardcoded for now; override with `TF_VAR_org_id`.

## Workflow

From this directory:

```sh
make plan      # shows what would be created
make apply     # creates the project + function (real Neon resources)
make show      # prints current state
make destroy   # tears everything down
make clean     # removes local .terraform/, state, plan files
```

## Configurable variables

| Variable        | Default                       | Override                  |
| --------------- | ----------------------------- | ------------------------- |
| `org_id`        | `org-twilight-cake-44366159`  | `TF_VAR_org_id`           |
| `region_id`     | `aws-us-east-2`               | `TF_VAR_region_id`        |
| `function_slug` | `tfmanual`                    | `TF_VAR_function_slug`    |
| `function_name` | `tfmanual`                    | `TF_VAR_function_name`    |

## Files

- `main.tf` — the config (project + function)
- `function.zip` — a minimal Node.js 24 bundle (`index.js` returning HTTP 200)
- `Makefile` — drives the workflow
- `.gitignore` — keeps local state out of git

## Regenerating the zip

```sh
cd test/manual
mkdir -p _bundle_tmp
echo "module.exports = async () => ({ statusCode: 200, body: 'ok' });" > _bundle_tmp/index.js
(cd _bundle_tmp && zip -q ../function.zip index.js)
rm -rf _bundle_tmp
```
