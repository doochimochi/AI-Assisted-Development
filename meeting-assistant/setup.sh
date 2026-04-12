#!/bin/bash
set -e

echo "=== Meeting Assistant Setup ==="

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1)
if [ "$MACOS_VERSION" -lt 14 ]; then
    echo "Error: macOS 14.0 (Sonoma) or later is required. You have $(sw_vers -productVersion)"
    exit 1
fi

# Check Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode not found. Install Xcode 15.4+ from the App Store."
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1 | awk '{print $2}' | cut -d. -f1)
if [ "$XCODE_VERSION" -lt 15 ]; then
    echo "Error: Xcode 15+ required. You have $(xcodebuild -version | head -1)"
    exit 1
fi

# Install xcodegen if missing
if ! command -v xcodegen &> /dev/null; then
    echo "Installing xcodegen..."
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew not found. Install from https://brew.sh"
        exit 1
    fi
    brew install xcodegen
fi

# Generate Xcode project
cd "$(dirname "$0")/MeetingAssistant"
echo "Generating Xcode project..."
xcodegen generate

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Open MeetingAssistant/MeetingAssistant.xcodeproj in Xcode"
echo "2. In Xcode: Signing & Capabilities > set your Team"
echo "3. Set environment variables (or add in Settings panel on first launch):"
echo "   export ANTHROPIC_API_KEY=your_key_here"
echo "   export DEEPGRAM_API_KEY=your_key_here"
echo "4. Build & Run (Cmd+R)"
echo "5. Grant Screen Recording permission when prompted"
echo ""
echo "Supported scenarios: Customer Call, Team Meeting, Technical War Room"
