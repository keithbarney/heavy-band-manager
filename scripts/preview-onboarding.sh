#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
preview_device="${SIMULATOR_UDID:-2E04F20D-CF80-460B-BA54-15C7B112CBFD}"
preview_output="${TMPDIR:-/tmp}/heavy-onboarding-derived"
preview_secrets="HeavyBandManager/Secrets.swift"
preview_created_secrets=0

cleanup() {
    if [[ "$preview_created_secrets" == 1 ]]; then
        rm -f "$preview_secrets"
    fi
}
trap cleanup EXIT

if [[ ! -f "$preview_secrets" ]]; then
    cat > "$preview_secrets" <<'EOF'
enum Secrets {
    static let supabaseURL = "https://example.invalid"
    static let supabaseAnonKey = "onboarding-preview-placeholder"
}
EOF
    preview_created_secrets=1
fi

xcodegen generate
xcodebuild -quiet -project HeavyBandManager.xcodeproj -scheme HeavyBandManager \
    -configuration Debug -destination "platform=iOS Simulator,id=$preview_device" \
    -derivedDataPath "$preview_output" CODE_SIGNING_ALLOWED=NO \
    PRODUCT_BUNDLE_IDENTIFIER=com.keithbarney.heavybandmanager.onboarding \
    'BUNDLE_DISPLAY_NAME=Onboarding Test' \
    ONBOARDING_PREVIEW_CONDITION=ONBOARDING_PREVIEW build

xcrun simctl terminate "$preview_device" com.keithbarney.heavybandmanager.onboarding 2>/dev/null || true
xcrun simctl install "$preview_device" "$preview_output/Build/Products/Debug-iphonesimulator/HeavyBandManager.app"
xcrun simctl launch "$preview_device" com.keithbarney.heavybandmanager.onboarding
open -a Simulator
