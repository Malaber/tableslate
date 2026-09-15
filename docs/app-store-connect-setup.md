# App Store Connect setup

No Apple-side setup is required for local development.

TableSlate uses:

- product name: TableSlate
- bundle identifier: `de.malaber.tableslate`
- SKU: stored in App Store Connect; it is not used by the build
- primary category: Games
- website: `https://tableslate.malaber.de`
- Apple app ID: `6812439555`

The App Store Connect record and bundle identifier exist. Version `0.1.0` build `1` was uploaded successfully on 2026-09-15 with the background command-line process in [`testflight-release.md`](testflight-release.md).

Store signing material only in the protected GitHub `testflight` environment. Keep automatic uploads disabled until the uploaded build has been tested on a physical iPhone and iPad.

The numeric Apple ID comes from App Store Connect; it is not the bundle identifier or website hostname.
