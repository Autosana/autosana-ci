# Autosana CI/CD Github Action
CI integration to upload new builds and trigger flows from github workflows

```
- uses: autosana/autosana-ci@v1
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    bundle-id: com.example.app
    platform: android
    build-path: build/app/outputs/flutter-apk/app-release.apk
```
