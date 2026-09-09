#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/project.yml"
XCODE_PROJECT="$ROOT_DIR/HeavyBandManager.xcodeproj"
SCHEME="HeavyBandManager"
RELEASE_DIR="${RELEASE_DIR:-$ROOT_DIR/.release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$RELEASE_DIR/HeavyBandManager.xcarchive}"
ARCHIVE_SOURCE_COMMIT="$ARCHIVE_PATH/BandPracticeSourceCommit"
EXPORT_OPTIONS="$ROOT_DIR/release/ExportOptions.plist"
PACKAGE_LOCK="$ROOT_DIR/release/Package.resolved"
GENERATED_PACKAGE_LOCK="$XCODE_PROJECT/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
SECRETS_FILE="$ROOT_DIR/HeavyBandManager/Secrets.swift"
TEAM_ID="BXKNJTU253"
DEFAULT_SIMULATOR_DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"

created_secrets=0
auth_args=()

cleanup_generated_secrets() {
  if [[ "$created_secrets" == "1" ]]; then
    rm -f "$SECRETS_FILE"
    created_secrets=0
  fi
}

trap cleanup_generated_secrets EXIT

usage() {
  cat <<'EOF'
Band Practice release commands

  make preflight
      Generate the Xcode project and run the unit tests without code signing.

  make version VERSION=1.3.0 [BUILD=8]
      Update project.yml. BUILD defaults to the current build plus one.

  make resolve-packages
      Refresh release/Package.resolved after changing package constraints.

  make archive
      Create a signed Release archive at .release/HeavyBandManager.xcarchive.

  CONFIRM_UPLOAD=1 make upload
      Upload the existing archive to App Store Connect/TestFlight.

  CONFIRM_UPLOAD=1 make release
      Run preflight, archive, and upload in sequence.

Required for API-key signing and upload:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_API_KEY_PATH

Required when HeavyBandManager/Secrets.swift is absent:
  SUPABASE_URL, SUPABASE_ANON_KEY

Optional:
  SIMULATOR_DESTINATION, RELEASE_DIR, ARCHIVE_PATH
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

read_setting() {
  local setting="$1"
  awk -v key="$setting" '
    $1 == key ":" {
      value = $2
      gsub(/"/, "", value)
      print value
      exit
    }
  ' "$PROJECT_FILE"
}

validate_version_settings() {
  local version build
  version="$(read_setting MARKETING_VERSION)"
  build="$(read_setting CURRENT_PROJECT_VERSION)"

  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    fail "MARKETING_VERSION must use major.minor.patch; found '$version'"
  [[ "$build" =~ ^[1-9][0-9]*$ ]] ||
    fail "CURRENT_PROJECT_VERSION must be a positive integer; found '$build'"

  echo "Version: $version ($build)"
}

validate_clean_checkout() {
  local status
  status="$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal)"
  [[ -z "$status" ]] ||
    fail "Refusing to create or upload a release from a dirty checkout. Commit or stash source changes first."
}

validate_upload_source() {
  local release_ref branch
  validate_clean_checkout

  release_ref="${GITHUB_REF:-}"
  branch="$(git -C "$ROOT_DIR" branch --show-current)"

  if [[ "$release_ref" == "refs/heads/main" || "$branch" == "main" ]]; then
    return
  fi

  fail "App Store uploads are restricted to main"
}

validate_archive_source() {
  local archive_commit source_commit
  [[ -f "$ARCHIVE_SOURCE_COMMIT" ]] ||
    fail "Archive source metadata not found at $ARCHIVE_SOURCE_COMMIT; create a fresh archive"

  archive_commit="$(tr -d '\r\n' < "$ARCHIVE_SOURCE_COMMIT")"
  source_commit="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  [[ "$archive_commit" == "$source_commit" ]] ||
    fail "Archive was built from $archive_commit, but the current checkout is $source_commit"
}

validate_archive_version() {
  local archive_plist archive_version archive_build source_version source_build
  archive_plist="$ARCHIVE_PATH/Products/Applications/HeavyBandManager.app/Info.plist"
  [[ -f "$archive_plist" ]] ||
    fail "Archived app Info.plist not found at $archive_plist"

  archive_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$archive_plist")"
  archive_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$archive_plist")"
  source_version="$(read_setting MARKETING_VERSION)"
  source_build="$(read_setting CURRENT_PROJECT_VERSION)"

  [[ "$archive_version" == "$source_version" && "$archive_build" == "$source_build" ]] ||
    fail "Archive version $archive_version ($archive_build) does not match project.yml $source_version ($source_build)"
}

write_secrets() {
  local supabase_url="$1"
  local supabase_anon_key="$2"

  RELEASE_SUPABASE_URL="$supabase_url" RELEASE_SUPABASE_ANON_KEY="$supabase_anon_key" \
    python3 - "$SECRETS_FILE" <<'PY'
import json
import os
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(
    "import Foundation\n\n"
    "enum Secrets {\n"
    f"    static let supabaseURL = {json.dumps(os.environ['RELEASE_SUPABASE_URL'])}\n"
    f"    static let supabaseAnonKey = {json.dumps(os.environ['RELEASE_SUPABASE_ANON_KEY'])}\n"
    "}\n"
)
PY
  created_secrets=1
}

ensure_test_secrets() {
  local test_url test_key
  if [[ -f "$SECRETS_FILE" ]]; then
    return
  fi

  test_url="${SUPABASE_URL:-https://example.supabase.co}"
  test_key="${SUPABASE_ANON_KEY:-ci-placeholder}"
  write_secrets "$test_url" "$test_key"
}

ensure_release_secrets() {
  if [[ -f "$SECRETS_FILE" ]]; then
    return
  fi

  [[ -n "${SUPABASE_URL:-}" ]] ||
    fail "SUPABASE_URL is required when HeavyBandManager/Secrets.swift is absent"
  [[ -n "${SUPABASE_ANON_KEY:-}" ]] ||
    fail "SUPABASE_ANON_KEY is required when HeavyBandManager/Secrets.swift is absent"
  write_secrets "$SUPABASE_URL" "$SUPABASE_ANON_KEY"
}

configure_authentication_arguments() {
  local supplied=0
  auth_args=()
  [[ -n "${ASC_KEY_ID:-}" ]] && supplied=$((supplied + 1))
  [[ -n "${ASC_ISSUER_ID:-}" ]] && supplied=$((supplied + 1))
  [[ -n "${ASC_API_KEY_PATH:-}" ]] && supplied=$((supplied + 1))

  if [[ "$supplied" == "0" ]]; then
    return
  fi

  [[ "$supplied" == "3" ]] ||
    fail "ASC_KEY_ID, ASC_ISSUER_ID, and ASC_API_KEY_PATH must be provided together"
  [[ -f "$ASC_API_KEY_PATH" ]] ||
    fail "App Store Connect API key not found at ASC_API_KEY_PATH"
  local key_mode
  key_mode="$(stat -f '%Lp' "$ASC_API_KEY_PATH")"
  [[ "$key_mode" =~ ^[0-7]{3,4}$ ]] ||
    fail "Could not verify App Store Connect API key permissions"
  (( (8#$key_mode & 077) == 0 )) ||
    fail "App Store Connect API key must not be readable by group or other users (mode: $key_mode)"

  auth_args=(
    "-authenticationKeyPath" "$ASC_API_KEY_PATH"
    "-authenticationKeyID" "$ASC_KEY_ID"
    "-authenticationKeyIssuerID" "$ASC_ISSUER_ID"
  )
}

generate_project() {
  require_command xcodegen
  (cd "$ROOT_DIR" && xcodegen generate)
  [[ -f "$PACKAGE_LOCK" ]] ||
    fail "Package lock not found at $PACKAGE_LOCK"
  mkdir -p "$(dirname "$GENERATED_PACKAGE_LOCK")"
  cp "$PACKAGE_LOCK" "$GENERATED_PACKAGE_LOCK"
}

resolve_packages() {
  require_command xcodegen
  require_command xcodebuild

  (cd "$ROOT_DIR" && xcodegen generate)
  rm -f "$GENERATED_PACKAGE_LOCK"
  xcodebuild -resolvePackageDependencies \
    -project "$XCODE_PROJECT" \
    -scheme "$SCHEME"
  [[ -f "$GENERATED_PACKAGE_LOCK" ]] ||
    fail "Xcode did not generate Package.resolved"
  cp "$GENERATED_PACKAGE_LOCK" "$PACKAGE_LOCK"
  echo "Updated $PACKAGE_LOCK"
}

preflight() {
  require_command xcodebuild
  require_command python3
  require_command git

  validate_version_settings

  if git -C "$ROOT_DIR" ls-files --error-unmatch HeavyBandManager/Secrets.swift >/dev/null 2>&1; then
    fail "HeavyBandManager/Secrets.swift is tracked by git"
  fi

  if ! grep -Eq 'SCREENSHOT_MODE[[:space:]]*=[[:space:]]*false' "$ROOT_DIR/HeavyBandManager/Views/AuthGate.swift"; then
    fail "SCREENSHOT_MODE must be false before release"
  fi

  ensure_test_secrets
  generate_project
  mkdir -p "$RELEASE_DIR"

  xcodebuild test \
    -quiet \
    -onlyUsePackageVersionsFromResolvedFile \
    -project "$XCODE_PROJECT" \
    -scheme "$SCHEME" \
    -destination "${SIMULATOR_DESTINATION:-$DEFAULT_SIMULATOR_DESTINATION}" \
    -derivedDataPath "$RELEASE_DIR/DerivedData" \
    PRODUCT_BUNDLE_IDENTIFIER=com.keithbarney.heavybandmanager.ci \
    CODE_SIGNING_ALLOWED=NO

  xcodebuild build \
    -quiet \
    -onlyUsePackageVersionsFromResolvedFile \
    -project "$XCODE_PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$RELEASE_DIR/DerivedData" \
    CODE_SIGNING_ALLOWED=NO

  cleanup_generated_secrets
}

set_version() {
  local version="${1:-}"
  local requested_build="${2:-}"
  local current_build next_build

  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    fail "VERSION must use major.minor.patch"

  current_build="$(read_setting CURRENT_PROJECT_VERSION)"
  [[ "$current_build" =~ ^[1-9][0-9]*$ ]] ||
    fail "Current build number is not a positive integer"
  next_build="${requested_build:-$((current_build + 1))}"
  [[ "$next_build" =~ ^[1-9][0-9]*$ ]] ||
    fail "BUILD must be a positive integer"
  (( next_build > current_build )) ||
    fail "BUILD must be greater than the current build ($current_build)"

  python3 - "$PROJECT_FILE" "$version" "$next_build" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
build = sys.argv[3]
text = path.read_text()
text, version_count = re.subn(
    r'(?m)^(\s*MARKETING_VERSION:\s*)"?[^"\n]+"?$',
    rf'\g<1>"{version}"',
    text,
    count=1,
)
text, build_count = re.subn(
    r'(?m)^(\s*CURRENT_PROJECT_VERSION:\s*)[^\n]+$',
    rf'\g<1>{build}',
    text,
    count=1,
)
if version_count != 1 or build_count != 1:
    raise SystemExit("Could not update version settings in project.yml")
path.write_text(text)
PY

  generate_project
  echo "Updated Band Practice to $version ($next_build) in project.yml"
  echo "Review and commit project.yml before uploading."
}

archive() {
  require_command xcodebuild
  require_command python3
  validate_clean_checkout
  validate_version_settings
  ensure_release_secrets
  generate_project
  mkdir -p "$RELEASE_DIR"

  configure_authentication_arguments

  xcodebuild archive \
    -project "$XCODE_PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -onlyUsePackageVersionsFromResolvedFile \
    ${auth_args[@]+"${auth_args[@]}"}

  git -C "$ROOT_DIR" rev-parse HEAD > "$ARCHIVE_SOURCE_COMMIT"

  echo "Archive created: $ARCHIVE_PATH"
}

upload() {
  [[ "${CONFIRM_UPLOAD:-0}" == "1" ]] ||
    fail "Upload not confirmed. Run with CONFIRM_UPLOAD=1."
  [[ -d "$ARCHIVE_PATH" ]] ||
    fail "Archive not found at $ARCHIVE_PATH; run make archive first"
  [[ -f "$EXPORT_OPTIONS" ]] ||
    fail "Export options not found at $EXPORT_OPTIONS"

  validate_upload_source
  validate_archive_source
  validate_archive_version
  configure_authentication_arguments
  [[ "${#auth_args[@]}" -gt 0 ]] ||
    fail "App Store Connect API-key authentication is required for upload"

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$RELEASE_DIR/Export" \
    -allowProvisioningUpdates \
    ${auth_args[@]+"${auth_args[@]}"}

  echo "Upload accepted by App Store Connect. Wait for processing before TestFlight validation."
}

case "${1:-help}" in
  help|-h|--help)
    usage
    ;;
  preflight|test)
    preflight
    ;;
  version)
    set_version "${2:-}" "${3:-}"
    ;;
  resolve-packages)
    resolve_packages
    ;;
  archive)
    archive
    ;;
  upload)
    upload
    ;;
  release)
    preflight
    archive
    upload
    ;;
  clean)
    [[ "$RELEASE_DIR" == "$ROOT_DIR/.release" ]] ||
      fail "Refusing to remove non-default RELEASE_DIR"
    rm -rf "$RELEASE_DIR"
    echo "Removed $RELEASE_DIR"
    ;;
  *)
    usage >&2
    fail "Unknown command: $1"
    ;;
esac
