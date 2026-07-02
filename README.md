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
- `environment`: Environment name such as `staging` or `production`
- `api-url`: Override the API base URL. Defaults to `https://backend.autosana.ai`
- `variables`: Key-value variables exposed to flow instructions via `${env:KEY}`. Use `KEY1=VALUE1,KEY2=VALUE2`.
- `suite-ids`: Comma-separated suite UUIDs to run after upload
- `flow-ids`: Comma-separated flow UUIDs to run after upload
- `tags`: Comma-separated tag names to run after upload (e.g. `smoke` or `smoke,regression`). Runs the union of every suite and flow carrying any of the given tags, so you can replace long `flow-ids` lists with a single tag. Combine with `suite-ids`/`flow-ids` to add to the selection. If no suite or flow matches, the action fails.
- `web-browser`: Web only. Playwright engine to run on — `chrome` (default, real Google Chrome with proprietary codecs and DRM), `chromium` (bundled Chromium engine, no codecs / DRM), `firefox`, or `edge`. Aliases accepted: `msedge` → `edge`. Ignored for mobile.
- `wait`: Whether to wait for triggered flows to finish and gate the job on their result. Defaults to `true`. Set to `false` to trigger the flows, print their run links, and exit immediately without blocking CI (fire-and-forget). Only applies when `suite-ids` or `flow-ids` are provided.

### Fire-and-forget runs

By default, when you pass `suite-ids`/`flow-ids` the action waits for the flows to finish so the job's exit code reflects the test result. To instead trigger the runs and let CI move on while tests execute on Autosana, set `wait: false`:

```yaml
- uses: autosana/autosana-ci@main
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    platform: ios
    bundle-id: com.example.app
    build-path: ./build/MyApp.app
    suite-ids: "uuid-1,uuid-2"
    wait: false
```

Platform-specific required inputs:

- Mobile (`android` or `ios`): `bundle-id`, `build-path`
- Web (`web`): `app-id`, `url`

## Example with optional inputs

Instead of maintaining a long `flow-ids` list, tag your suites and flows in
Autosana and run them all by tag:

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
    tags: smoke
```
