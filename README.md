# autosana-ci
CI integration to upload new builds and trigger flows from github workflows

```
Instead of all those 3 endpoints I want to use the package which shoudl be like:

- uses: autosana/ci-upload-action@v1
  with:
    api-key: ${{ secrets.AUTOSANA_KEY }}
    bundle-id: ${{ secrets.BUNDLE_ID }}
    platform: android
    filename: app-release.apk
```
