#!/bin/bash
# build_dmg.sh — Build MeetingAssistant.app and package as .dmg
#
# Prerequisites:
#   brew install xcodegen
#   MeetingAssistant/Keys.xcconfig must exist (copy from Keys.xcconfig.template)
#
# Usage:
#   chmod +x build_dmg.sh
#   ./build_dmg.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/MeetingAssistant"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/MeetingAssistant.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$SCRIPT_DIR/MeetingAssistant.dmg"

# ── 1. Check Keys.xcconfig ──────────────────────────────────────────────────
if [ ! -f "$PROJECT_DIR/Keys.xcconfig" ]; then
    echo "❌ Keys.xcconfig not found."
    echo "   Copy $PROJECT_DIR/Keys.xcconfig.template to $PROJECT_DIR/Keys.xcconfig"
    echo "   and fill in your API keys, then re-run."
    exit 1
fi

# ── 2. Generate Xcode project ───────────────────────────────────────────────
echo "▶ Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate --quiet

# ── 3. Archive ──────────────────────────────────────────────────────────────
echo "▶ Archiving (Release)..."
xcodebuild archive \
  -project MeetingAssistant.xcodeproj \
  -scheme MeetingAssistant \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -quiet

# ── 4. Export .app ──────────────────────────────────────────────────────────
echo "▶ Exporting .app..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist ExportOptions.plist \
  -quiet

# ── 5. Create DMG ───────────────────────────────────────────────────────────
echo "▶ Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Meeting Assistant" \
  -srcfolder "$EXPORT_PATH/MeetingAssistant.app" \
  -ov -format UDZO \
  "$DMG_PATH"

echo ""
echo "✅ Done: $DMG_PATH"
echo ""
echo "Installation instructions:"
echo "  1. Double-click MeetingAssistant.dmg"
echo "  2. Drag MeetingAssistant.app to /Applications"
echo "  3. First launch: right-click → Open (to bypass Gatekeeper)"
echo "  4. Grant Screen Recording permission when prompted"
