# Publication preparation report

## Scope and history

This is a local publication candidate prepared for owner review. Nothing was
published or pushed. The export has fresh history with one initial commit and no
remote. The original GitHub repository remains private and was not modified.

The Flutter application, Dart relay, React dashboard, native project files,
existing tests, research notes, source assets, and dependency lockfiles are
preserved. No application code, feature, dependency, or test was changed or added.

## Removed files

- `CardioQuest.ipa` - removed a packaged distribution artifact. Archive inspection
  found only an empty payload directory, not an application executable. Retaining
  an archive is unnecessary for building from source and risks carrying signing
  data if later replaced by a real build.

No other source-snapshot file was removed. Generated package caches and build
outputs from local validation were discarded and are not publication content.

## Substitutions and documentation

- Removed the personal notification destination and the email publishing block
  from `codemagic.yaml`. The unsigned release build, artifact packaging, and
  release verification scripts remain unchanged. No notifications are enabled.
- Expanded `.gitignore` to exclude local environment files and common signing
  credentials in addition to the existing local fitness configuration exclusion.
- Preserved the README's feature, protocol, gameplay, and provider setup guidance.
  Added source-backed architecture, engineering decisions, dashboard commands,
  validation results, signing requirements, and limits. Corrected native platform
  minimums and replaced an unsupported toolchain verification claim with the
  version actually tested.
- Updated `web/README.md` to match the locked build tools' Node.js requirement
  and use the dependency lockfile for installation.
- Retained `01-master-research.md` unchanged because it contains useful technical
  background and public references, with no private values found.

## Configuration and judgment calls

OAuth client IDs and secrets remain empty in the example configuration and are
read from compile-time configuration. Runtime token handling, secure storage,
OAuth state validation, refresh handling, and upload retries remain intact.
Public provider endpoints, package URLs, dependency attribution, and third-party
notices were retained. The mobile callback scheme and generic application bundle
identifiers were preserved consistently across the app and native projects.

The multiplayer client already defaults to loopback and exposes a configurable
server URL. The README's relay command now explicitly binds loopback because the
server's built-in default listens on all interfaces. The relay's request logging
uses the local process console. No owner endpoint or external log destination
was found. The dashboard makes no endpoint request without configuration and
uses generated fixtures rather than a recorded personal dataset.

The Gradle wrapper JAR is a build bootstrap dependency, not a packaged application,
so it remains. Its archive entries were inspected. All PNG assets remain, with
chunk metadata inspected. The app icon's text metadata contains creation and
modification dates only. No credentials or device identity were found in these
binary artifacts. Existing generated plugin registration source files and their
notices were retained because they belong to the supplied source snapshot.

## Verification performed

- Read source configuration, services, relay behavior, dashboard data loading,
  synthetic-data generation, native build settings, existing tests, and docs.
- Scanned the complete candidate tree, including documentation and binary data,
  for private network addresses, personal hostnames and paths, personal contact
  destinations, device/signing identities, and credential patterns. No unresolved
  private values were found. Candidate secret literals were reviewed as storage
  keys, protocol fields, empty configuration, or public dependency names.
- Compared source and output files, content hashes, and executable modes. All
  substantive application and test files are unchanged. Every source deletion
  is listed above. The immutable source snapshot was verified unchanged.
- `flutter pub get` passed with Flutter 3.38.5 and Dart 3.10.4 on Linux.
- `flutter analyze` passed with no issues.
- `flutter test --no-pub --reporter expanded` passed all 28 existing tests.
  Multiplayer tests use loopback and export tests use mocks.
- The standalone relay entry point was started on loopback with an ephemeral
  port. `/health` and `/` returned HTTP 200 with expected JSON. The process was
  stopped after the check.
- In `web/`, `npm ci --ignore-scripts --no-audit --no-fund`,
  `npm run typecheck`, and `npm run build` passed with Node.js 22.22.1 and
  npm 10.9.4. Generated dependencies and build output were removed afterward.
- Fresh local Git history, initial commit identity, tracked-file completeness,
  clean working tree, and absence of remotes were checked.

No dedicated secret-scanner product was run. The verification used targeted
pattern scans, archive and metadata inspection, and source review. These checks
reduce exposure but cannot prove that every possible secret format is absent.

## Residual risks and unverified behavior

- No hardware Bluetooth connection, mobile release build, hosted runner, Apple
  signing, notification, provider authorization, or real workout upload was run.
  Linux tests do not establish physical-device compatibility.
- `WearableService` is already a no-op implementation in the supplied source.
  Wearable health collection is unavailable. This preparation did not replace it.
- OAuth secrets embedded in mobile binaries are extractable. Production clients
  need a backend-owned secret exchange rather than relying on local build defines.
  Garmin upload requires approved partner endpoints and provider access.
- The relay trusts client telemetry and lacks account authentication. A public
  deployment needs its own access controls and abuse protection. Local testing
  does not establish production security.
- The iOS workflow builds unsigned artifacts and needs separate user-owned
  signing credentials for distribution. Android release currently uses debug
  signing and is not store-ready.
- Research notes contain historical claims, prices, and compatibility summaries
  that were preserved, not independently revalidated.
- Dependencies and third-party distribution rights need normal release review.
  No project license was added and no dependency vulnerability audit was claimed.

Owner review is still required before any publication.
