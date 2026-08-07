# Band Practice Calendar — Release Runbook

Band Practice Calendar is live on the App Store:
https://apps.apple.com/us/app/band-practice-calendar/id6763776073

- Apple ID: `6763776073`
- Bundle ID: `com.keithbarney.heavybandmanager`
- Team ID: `BXKNJTU253`
- Current repository version: `1.2.0 (7)`
- Xcode project source of truth: `project.yml`
- Linear release work: Band Practice project, `HVY` team

The pipeline validates, archives, and uploads a build to App Store Connect. It
does not select a build for App Review or release a version to customers.
Those remain explicit approval steps.

## One-time GitHub setup

Create a GitHub environment named `app-store`. Add a required reviewer if the
repository plan supports environment protection rules, then add these
environment secrets:

| Secret | Value |
| --- | --- |
| `SUPABASE_URL` | Production Supabase project URL |
| `SUPABASE_ANON_KEY` | Production Supabase anonymous key |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect issuer ID |
| `ASC_API_KEY_BASE64` | Base64-encoded contents of the `.p8` private key |

Use an App Store Connect team API key with the minimum role Apple permits for
uploading builds. Downloaded `.p8` keys are only available once; store the
original outside the repository. Never put a key, issuer ID, Supabase
credential, certificate, or provisioning profile in source control.

To encode the API key for the GitHub secret:

```sh
base64 -i /secure/path/AuthKey_EXAMPLE.p8 | pbcopy
```

The release workflow uses Xcode automatic signing with the App Store Connect
API key. If Apple denies certificate or provisioning access, confirm the key's
role and access to Certificates, Identifiers & Profiles in App Store Connect.

## Update workflow

### 1. Track and prepare the update

Create or locate the Linear issue for the update before implementation. Keep
scope, acceptance criteria, validation, review, QA, and the release decision
current there.

Update the version in `project.yml`:

```sh
make version VERSION=1.3.0
```

The build number increments automatically. To choose a higher build:

```sh
make version VERSION=1.3.0 BUILD=10
```

Commit the `project.yml` change with the release code. Do not edit the ignored
`.xcodeproj`.

### 2. Run local preflight

```sh
make preflight
```

Preflight:

- verifies `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`;
- refuses a tracked `HeavyBandManager/Secrets.swift`;
- verifies `SCREENSHOT_MODE` is disabled;
- regenerates the Xcode project;
- runs the unit tests under an isolated CI bundle identifier on an iPhone
  simulator without code signing;
- compiles the unsigned Release configuration for a generic iPhone.

Override the simulator when needed:

```sh
SIMULATOR_DESTINATION='platform=iOS Simulator,name=iPhone 17' make preflight
```

### 3. Merge only after review and QA

The `iOS CI` GitHub workflow runs the same preflight for pull requests and
updates to `main`. Before merging a production-bound update:

- automated checks are green;
- independent code review is complete;
- QA passed on the actual build;
- screenshots and listing copy are current if the UI changed;
- privacy labels and permission descriptions still match behavior;
- release notes are drafted;
- the version and build are unique in App Store Connect.

### 4. Upload the selected commit

In GitHub Actions, choose **App Store upload** → **Run workflow**:

1. Select the merged release ref, normally `main`.
2. Enter `UPLOAD` in the confirmation field.
3. Approve the `app-store` environment deployment if prompted.

The job reruns preflight, creates a signed archive, and uploads it to App Store
Connect. Uploads are restricted to `main`.
The uploader also refuses a dirty checkout, an archive built from a different
Git commit, or an archive whose version/build does not match `project.yml`.
The job does not submit the build for review.

The same pipeline can run locally when Xcode signing is configured:

```sh
ASC_KEY_ID='…' \
ASC_ISSUER_ID='…' \
ASC_API_KEY_PATH='/secure/path/AuthKey_EXAMPLE.p8' \
CONFIRM_UPLOAD=1 \
make release
```

Local release archives and export output are written under `.release/`.
Local uploads are also restricted to a clean `main` checkout.

### 5. TestFlight gate

Wait for processing to complete in App Store Connect, then install the uploaded
build through TestFlight on a physical iPhone. Verify:

- sign in and account deletion;
- calendar permission denial, grant, and re-enable;
- availability calculation and multi-band switching;
- scheduling, updating, and cancelling a practice;
- notifications;
- support and privacy links;
- version/build shown by App Store Connect match `project.yml`.

Record the device, OS, build, result, and any defects in Linear.

### 6. App Review and release approval

After TestFlight passes, prepare the version in App Store Connect:

- paste reviewed “What’s New” copy;
- confirm screenshots and metadata;
- confirm privacy answers and export compliance;
- select the processed build;
- resolve every App Store Connect warning.

Present the release evidence and remaining risk to Keith. Only after explicit
approval:

1. submit the version for App Review;
2. choose the approved release mode;
3. release it to customers after Apple approval.

### 7. Post-release

After the version is live:

- install/update from the public App Store;
- run a focused production smoke test;
- record version, build, submission date, approval date, release date, review
  duration, and smoke-test result in Linear;
- mark the release issue complete only after the live smoke test passes.

## Local commands

```sh
make help
make preflight
make version VERSION=1.3.0
make resolve-packages
make archive
CONFIRM_UPLOAD=1 make upload
CONFIRM_UPLOAD=1 make release
make clean-release
```

`make upload` uses an existing archive. `make release` performs preflight,
archive, and upload in sequence.

Run `make resolve-packages` only after deliberately changing package
constraints in `project.yml`, then review and commit `release/Package.resolved`.
