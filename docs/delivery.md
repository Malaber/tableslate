# Delivery

## Local checks

```bash
.venv/bin/inv generate-ios-project
.venv/bin/inv check-ios-package
.venv/bin/inv build-ios-simulator --device-name="iPhone 17 Pro"
.venv/bin/inv ios-ui-e2e --device-name="iPhone 17 Pro"
.venv/bin/inv ios-ui-e2e --device-name="iPad Pro 13-inch (M5)" --artifact-dir="e2e-artifacts/ios-ipad"
```

The Swift package gate emits a line-coverage summary and enforces the 99% TableSlateCore target by default. Set `TABLESLATE_COVERAGE_MINIMUM` only when deliberately testing a different threshold locally.

The Xcode project is reproducibly generated from `ios/TableSlateIOS/project.yml` and must not be committed.

## Continuous integration

`ci.yml` calls `ios-checks.yml` for portable Swift tests and macOS iPhone/iPad UI checks. `pages.yml` publishes `website/` without a build step. TestFlight stays gated behind repository configuration until the uploaded build has been tested and protected CI signing is configured.

## Release stages

1. Make package, iPhone, and iPad checks green.
2. Smoke-test score entry, termination recovery, appearance modes, import, and Dynamic Type on physical devices.
3. Archive and upload from the command line using [`testflight-release.md`](testflight-release.md). Do not open the Xcode GUI.
4. Test the processed build through an internal TestFlight group on physical iPhone and iPad.
5. Configure the protected `testflight` environment and set `TESTFLIGHT_UPLOAD_ENABLED` only after that testing succeeds.
6. Enable automatic current-main delivery; never upload a superseded commit.
