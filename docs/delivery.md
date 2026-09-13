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

`ci.yml` calls `ios-checks.yml` for portable Swift tests and macOS iPhone/iPad UI checks. `pages.yml` publishes `website/` without a build step. TestFlight stays gated behind repository configuration until App Store Connect provisioning is complete.

## Release stages

1. Make package, iPhone, and iPad checks green.
2. Smoke-test score entry, termination recovery, appearance modes, import, and Dynamic Type on physical devices.
3. Register `de.malaber.tableslate`, the App Store Connect record, and a TableSlate-specific distribution profile.
4. Configure the protected `testflight` environment and set `TESTFLIGHT_UPLOAD_ENABLED` only after a successful manual upload.
5. Enable automatic current-main delivery; never upload a superseded commit.
