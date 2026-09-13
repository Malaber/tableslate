# App Store Connect setup

No Apple-side setup is required for local development.

When TableSlate is ready for TestFlight, create:

- product name: TableSlate
- bundle identifier: `de.malaber.tableslate`
- suggested SKU: `tableslate-ios`
- primary category: Games
- website: `https://tableslate.malaber.de`

Then create the App Store Connect app record and TableSlate-specific provisioning profile. Store signing material only in the protected GitHub `testflight` environment. Keep automatic uploads disabled until a signed archive has been uploaded manually and tested on a physical iPhone and iPad.

The numeric Apple ID comes from App Store Connect; it is not the bundle identifier or website hostname.
