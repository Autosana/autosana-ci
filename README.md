# Autosana CI/CD Github Action

CI integration to upload new builds and trigger flows from GitHub workflows.

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
- `suite-ids`: Comma-separated suite UUIDs to run after upload
- `flow-ids`: Comma-separated flow UUIDs to run after upload
- `labels`: Comma-separated label names to run after upload (e.g. `smoke` or `smoke,regression`). Runs the union of every suite and flow carrying any of the given labels, so you can replace long `flow-ids` lists with a single label. Combine with `suite-ids`/`flow-ids` to add to the selection. If no suite or flow matches, the action fails.
- `web-browser`: Web only. Playwright engine to run on — `chrome` (default, real Google Chrome with proprietary codecs and DRM), `chromium` (bundled Chromium engine, no codecs / DRM), `firefox`, or `edge`. Aliases accepted: `msedge` → `edge`. Ignored for mobile.
- `dependencies`: Web runs only. A JSON array overriding the web app's default Chrome extension loadout for this run. Omit it to inherit defaults, pass `'[]'` to load no extensions, or provide extension app UUIDs and optional build pins such as `'["app-uuid",{"app_id":"app-uuid","app_build_id":"build-uuid"}]'`. Requires `suite-ids`, `flow-ids`, or `labels`.
- `wait`: Whether to wait for triggered flows to finish and gate the job on their result. Defaults to `true`. Set to `false` to trigger the flows, print their run links, and exit immediately without blocking CI (fire-and-forget). Applies when `suite-ids`, `flow-ids`, or `labels` trigger tests.

### Fire-and-forget runs

By default, when you pass `suite-ids`, `flow-ids`, or `labels`, the action waits for the flows to finish so the job's exit code reflects the test result. To instead trigger the runs and let CI move on while tests execute on Autosana, set `wait: false`:

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

### Web extension loadout overrides

The `dependencies` input changes the Chrome extensions loaded for direct web
runs triggered by `suite-ids`, `flow-ids`, or `labels`:

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

This input is not supported for mobile or Chrome extension uploads.

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
