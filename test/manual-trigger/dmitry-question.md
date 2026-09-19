# Question for Dmitry

Working on `neon_trigger` on the sync fork (`randoneering/terraform-provider-neon-sync`).
Resource implements CRUD via `client.CreateProjectBranchTrigger`,
`client.UpdateProjectBranchTrigger`, etc. against `kislerdm/neon-sdk-go v0.24.0`.

Apply against a real project fails with:

```
[HTTP Code: 400][Error Code: ]
invalid request: operation CreateProjectBranchTrigger: decode request:
decode application/json: decode field OneOf: unable to detect sum type variant
```

Same error for UpdateProjectBranchTrigger.

## What's happening

The SDK's `TriggerCreateRequest` type embeds two structs that both have
`type`, `name`, `function_slug`, `enabled`, `function_path` fields with
matching `json` tags:

```go
type TriggerCreateRequest struct {
    ScheduleTriggerCreateRequest
    StorageObjectCreatedTriggerCreateRequest
}

type ScheduleTriggerCreateRequest struct {
    Enabled      *bool                              `json:"enabled,omitempty"`
    FunctionPath *string                            `json:"function_path,omitempty"`
    FunctionSlug string                             `json:"function_slug"`
    Name         string                             `json:"name"`
    Schedule     FunctionTriggerSchedule            `json:"schedule"`
    Type         ScheduleTriggerCreateRequestType  `json:"type"`
}

type StorageObjectCreatedTriggerCreateRequest struct {
    Enabled             *bool                                   `json:"enabled,omitempty"`
    FunctionPath        *string                                 `json:"function_path,omitempty"`
    FunctionSlug        string                                  `json:"function_slug"`
    Name                string                                  `json:"name"`
    StorageObjectCreated FunctionTriggerStorageObjectCreated     `json:"storage_object_created"`
    Type                StorageObjectCreatedTriggerCreateRequestType `json:"type"`
}
```

`TriggerUpdateRequest` has the same shape via
`ScheduleTriggerUpdateRequest` + `StorageObjectCreatedTriggerUpdateRequest`.

When the provider marshals this via the SDK's `requestHandler`
(`json.Marshal(reqPayload)`), Go drops the overlapping promoted fields
per the documented rule: two fields at the same depth with the same JSON
tag -> both ignored. The discriminator `type` is gone from the body, and
so are `name` and `function_slug`. Only the unambiguous nested blocks
(`schedule`, `storage_object_created`) are emitted.

A small probe confirms this:

```go
cfg := neon.TriggerCreateRequest{}
typeVal, _ := neon.NewScheduleTriggerCreateRequestType("schedule")
cfg.ScheduleTriggerCreateRequest.Type = typeVal
cfg.ScheduleTriggerCreateRequest.Name = "my-trigger"
cfg.ScheduleTriggerCreateRequest.FunctionSlug = "myfn"
cfg.ScheduleTriggerCreateRequest.Schedule = neon.FunctionTriggerSchedule{
    Cron: "*/5 * * * *",
}
b, _ := json.Marshal(cfg)
fmt.Println(string(b))
// {"schedule":{"cron":"*/5 * * * *"},"storage_object_created":{"bucket_name":""}}
```

No `type`, no `name`, no `function_slug`. The server sees both nested
blocks and can't pick a `oneOf` variant.

`CreateProjectBranchTrigger` and `UpdateProjectBranchTrigger` are both
broken because they take the embedded-discriminated request type.
`ListProjectBranchTriggers`, `GetProjectBranchTrigger`, and
`DeleteProjectBranchTrigger` work fine (no request body).

## What I tried

First pass used the SDK directly. Hit the 400 above. Looked at the SDK
struct layout, concluded it can't marshal correctly because of the
field-name overlap.

Last time we hit a similar error on neon_function you came back and
resolved it internally (commit `a557e1d` "fix the types conversion" -
changing `EnvironmentVariables types.Map` to `map[string]string`,
removing wrapper functions). No SDK workaround, no upstream ticket.

## What I'm asking

Is there a known SDK pattern for oneOf discriminator types that I'm
missing? Or is this a real bug in the embedded struct definition that
needs an SDK change? If it's the latter, can you take a look?

Three possibilities I see:
1. The SDK has a usage pattern that makes the JSON marshaling work
   that I'm not aware of (a MarshalJSON method somewhere I missed, a
   constructor that bypasses the issue, etc.)
2. The SDK needs a fix: a custom MarshalJSON on `TriggerCreateRequest`
   and `TriggerUpdateRequest`, or a non-embedded layout where the
   discriminator is set explicitly.
3. The bug is in our provider code and shouldn't be hit at all - we are
   somehow constructing the request wrong.

The provider file is at
`provider/resource_trigger.go` on the sync fork. Test config is in
`test/manual-trigger/main.tf`.

Thanks.
