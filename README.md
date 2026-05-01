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
- `web-browser`: Web only. Playwright engine to run on — `chrome` (default, real Google Chrome with proprietary codecs and DRM), `chromium` (bundled Chromium engine, no codecs / DRM), `firefox`, or `edge`. Aliases accepted: `msedge` → `edge`. Ignored for mobile.

Platform-specific required inputs:

- Mobile (`android` or `ios`): `bundle-id`, `build-path`
- Web (`web`): `app-id`, `url`

## Example with optional inputs

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
    flow-ids: "uuid-1,uuid-2"
```
