# Autosana CI/CD Github Action

CI integration to upload new builds and trigger flows from GitHub workflows.

See the [Autosana GitHub Action guide](https://docs.autosana.ai/ci-cd-integration)
for setup instructions and complete workflow examples.

## Basic usage

```yaml
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: android
    bundle-id: com.example.app
    build-path: build/app/outputs/flutter-apk/app-release.apk
```

## iOS usage

```yaml
# Simulator build (zipped .app)
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: ios
    bundle-id: com.example.app
    build-path: build/MyApp.app.zip

# Real-device build (.ipa) — required to run on physical devices
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: ios
    bundle-id: com.example.app
    build-path: build/MyApp.ipa
```

Upload the artifact with its real extension — don't re-zip a `.ipa`. The
extension determines the target: a `.ipa` runs on **real devices**, while a
zipped `.app` bundle (`.zip`) runs on the **iOS simulator**.

For apps that use Team-ID-prefixed keychain access groups, set
`enable-ios-keychain-access-group-remapping: true` once. The preference is
saved on the app and inherited by future `.ipa` uploads. Set it to `false` to
disable remapping for the app.

## Web usage

```yaml
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: web
    app-id: my-web-app
    url: https://preview.example.com
```

## Optional inputs

Shared optional inputs:

- `name`: Display name for the app
- `environment`: Environment name such as `staging` or `production`. Chrome extensions are organization-wide and ignore this input.
- `api-url`: Override the API base URL. Defaults to `https://backend.autosana.ai`
- `variables`: Key-value variables exposed to flow instructions via `${env:KEY}`. Use `KEY1=VALUE1,KEY2=VALUE2`.
- `suite-ids`: Comma-separated suite UUIDs to run after a web or mobile upload
- `flow-ids`: Comma-separated flow UUIDs to run after a web or mobile upload
- `suite-keys`: Comma-separated code-managed suite keys to run from the checked-out commit
- `flow-keys`: Comma-separated code-managed flow keys to run from the checked-out commit
- `labels`: Comma-separated label names to run after a web or mobile upload (e.g. `smoke` or `smoke,regression`). Runs the union of every suite and flow carrying any of the given labels, so you can replace long `flow-ids` lists with a single label. Combine with `suite-ids`/`flow-ids` to add to the selection. If no suite or flow matches, the action fails.
- `web-browser`: Web only. Playwright engine to run on — `chrome` (default, real Google Chrome with proprietary codecs and DRM), `chromium` (bundled Chromium engine, no codecs / DRM), `firefox`, or `edge`. Aliases accepted: `msedge` → `edge`. Ignored for mobile.
- `dependencies`: Web runs only. A JSON array overriding the web app's default Chrome extension loadout for upload-triggered automations and direct runs. Omit it to inherit defaults, pass `'[]'` to load no extensions, or provide extension app UUIDs and optional build pins such as `'["app-uuid",{"app_id":"app-uuid","app_build_id":"build-uuid"}]'`. Requires a flow, suite, or label selector. Currently unsupported with `suite-keys`.
- `wait`: Whether to wait for triggered flows to finish and gate the job on their result. Defaults to `true`. Set to `false` to trigger the flows, print their run links, and exit immediately without blocking CI (fire-and-forget). Applies when any flow, suite, or label selector triggers tests.
- `enable-ios-keychain-access-group-remapping`: iOS `.ipa` only. Persist whether future IPA uploads should remap Team-ID-prefixed keychain access groups after cloud re-signing. Omit it to inherit the app's saved preference.
- `physical-device`: Single-device mobile runs only. Set to `true` to run on real hardware. Defaults to `false`.
- `device-model`: Single-device mobile runs only. Model from the Autosana device catalog, such as `Pixel 10 Pro`, or `latest`.
- `os-version`: Single-device mobile runs only. OS version supported by the selected model, such as `17`, or `latest`.
- `devices`: Multi-device mobile runs only. JSON array of ordered device selections. Two-device flows currently require exactly two objects.

Direct test runs resolve code-managed flows, suites, and labels from the exact
checked-out commit. GitHub repository metadata and a full commit SHA are required
when any test selector is provided.

Use stable YAML keys instead of Autosana UUIDs for code-managed targets. Flow and
suite keys can be combined with each other, but not with ID or label selectors:

```yaml
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: android
    bundle-id: com.example.app
    build-path: build/app-release.apk
    flow-keys: "auth/login,checkout"
    suite-keys: "smoke"
```

Device inputs apply when any flow, suite, or label selector triggers a run. Use
`latest` to make rolling model and OS selection explicit in checked-in workflows:

```yaml
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: android
    bundle-id: com.example.app
    build-path: build/app-release.apk
    suite-ids: "suite-uuid"
    physical-device: false
    device-model: latest
    os-version: latest
```

Set either input independently and use `latest` (or omit the other input) to
keep that dimension rolling. To pin both the model and OS:

```yaml
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: android
    bundle-id: com.example.app
    build-path: build/app-release.apk
    suite-ids: "suite-uuid"
    physical-device: false
    device-model: Pixel 10 Pro
    os-version: "17"
```

Omitting `device-model` and `os-version` retains the same rolling-latest
behavior for backward compatibility.

For a flow or suite configured to use two devices, pass an ordered JSON array
through `devices`. Each entry supports `physical`, `model`, and `os_version`.
Do not combine `devices` with the single-device selection inputs.

```yaml
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: ios
    bundle-id: com.example.app
    build-path: build/MyApp.ipa
    flow-ids: "two-device-flow-uuid"
    devices: |
      [
        {"physical": true, "model": "iPhone 17 Pro", "os_version": "26"},
        {"physical": true, "model": "iPhone 16 Pro", "os_version": "18"}
      ]
```

Use `[{"physical": false}, {"physical": false}]` for two rolling Latest
virtual devices. Mixed one-device and two-device targets are rejected by the
API.

### Fire-and-forget runs

By default, when you pass a flow, suite, or label selector, the action waits for the flows to finish so the job's exit code reflects the test result. To instead trigger the runs and let CI move on while tests execute on Autosana, set `wait: false`:

```yaml
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: ios
    bundle-id: com.example.app
    build-path: ./build/MyApp.app.zip
    suite-ids: "uuid-1,uuid-2"
    wait: false
```

Platform-specific required inputs:

- Mobile (`android` or `ios`): `bundle-id`, `build-path`
- Chrome extension (`chrome-extension`): `bundle-id`, `build-path` (a `.zip` containing the unpacked Manifest V3 extension)
- Web (`web`): `app-id`, `url`

Chrome extension Actions only upload extension builds. Do not pass flow, suite,
or label selectors to that step. Attach the extension to a web app, then
trigger tests in a separate `platform: web` Action step; use that app's default
extensions or the web step's `dependencies` override.

### Web extension loadout overrides

The `dependencies` input changes the Chrome extensions loaded for web runs
triggered by the upload's configured automations and by any flow, suite, or
label selector:

```yaml
# Omit dependencies to inherit the web app's configured defaults.
labels: smoke

# Run without any configured extensions.
dependencies: '[]'

# Load an extension's active build plus a pinned build of another extension.
dependencies: >-
  ["11111111-1111-1111-1111-111111111111",
   {"app_id":"22222222-2222-2222-2222-222222222222",
    "app_build_id":"33333333-3333-3333-3333-333333333333"}]
```

This input is not supported with `suite-keys`, mobile, or Chrome extension uploads.

## Example with optional inputs

Instead of maintaining a long `flow-ids` list, label your suites and flows in
Autosana and run them all by label:

```yaml
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: android
    bundle-id: com.example.app
    build-path: build/app/outputs/flutter-apk/app-release.apk
    name: Example App
    environment: staging
    variables: "TEST_ACCOUNT=qa-smoke,CHECKOUT_VARIANT=control"
    labels: smoke
```

### Scheduled workflows and trusted checkouts

Use `commit-sha`, `branch-name`, and `repo-full-name` when the workflow checks out trusted workflow code instead of the PR revision. Explicit inputs override event and checkout metadata. `commit-sha` must be a full 40-character SHA when selecting tests. The action pins web runs to the build returned by registration so concurrent previews cannot change the target.

The action gates its own workflow job. A scheduled workflow that tests another PR must publish a check on that PR's head SHA using `checks: write`; the scheduled job itself belongs to the scheduler's commit.
