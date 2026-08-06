#!/bin/bash

# =============================================================================
# LeelaChessZero Example App - Fresh Build & Install Script
# =============================================================================
# This script performs a complete clean build and installation of the example
# app on both Android and iOS devices/simulators.
#
# Usage:
#   ./run_example.sh [options]
#
# Options:
#   --android-only    Build and install only on Android
#   --ios-only        Build and install only on iOS
#   --skip-cmake      Skip CMake clean/rebuild
#   --skip-pods       Skip CocoaPods clean/reinstall
#   --device <id>     Target specific device ID
#   --help            Show this help message
# =============================================================================

set -e  # Exit on error

# Fix CocoaPods UTF-8 encoding issue
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$SCRIPT_DIR"

# Default options
BUILD_ANDROID=true
BUILD_IOS=true
SKIP_CMAKE=false
SKIP_PODS=false
TARGET_DEVICE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --android-only)
            BUILD_IOS=false
            shift
            ;;
        --ios-only)
            BUILD_ANDROID=false
            shift
            ;;
        --skip-cmake)
            SKIP_CMAKE=true
            shift
            ;;
        --skip-pods)
            SKIP_PODS=true
            shift
            ;;
        --device)
            TARGET_DEVICE="$2"
            shift 2
            ;;
        --help)
            head -30 "$0" | tail -25
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# =============================================================================
# Step 1: Clean Flutter artifacts
# =============================================================================

print_header "Step 1: Cleaning Flutter Artifacts"

cd "$EXAMPLE_DIR"

print_step "Running flutter clean..."
flutter clean

print_step "Removing pubspec.lock..."
rm -f pubspec.lock

print_step "Removing .dart_tool..."
rm -rf .dart_tool

cd "$PROJECT_ROOT"
print_step "Cleaning main package..."
flutter clean
rm -f pubspec.lock
rm -rf .dart_tool

print_success "Flutter artifacts cleaned"

# =============================================================================
# Step 2: Clean and rebuild CMake (Android)
# =============================================================================

if [ "$BUILD_ANDROID" = true ] && [ "$SKIP_CMAKE" = false ]; then
    print_header "Step 2: Fresh CMake Build (Android)"

    ANDROID_BUILD_DIR="$EXAMPLE_DIR/android/.cxx"
    GRADLE_BUILD_DIR="$EXAMPLE_DIR/android/app/build"
    PLUGIN_BUILD_DIR="$PROJECT_ROOT/android/.cxx"

    print_step "Removing Android CMake cache..."
    rm -rf "$ANDROID_BUILD_DIR"
    rm -rf "$PLUGIN_BUILD_DIR"

    print_step "Removing Android build artifacts..."
    rm -rf "$GRADLE_BUILD_DIR"
    rm -rf "$EXAMPLE_DIR/android/app/.cxx"
    rm -rf "$EXAMPLE_DIR/build"

    print_step "Removing Gradle caches..."
    rm -rf "$EXAMPLE_DIR/android/.gradle"
    rm -rf "$PROJECT_ROOT/android/.gradle"

    print_success "Android CMake cache cleared"
else
    if [ "$BUILD_ANDROID" = true ]; then
        print_warning "Skipping CMake clean (--skip-cmake)"
    fi
fi

# =============================================================================
# Step 3: Clean and reinstall CocoaPods (iOS)
# =============================================================================

if [ "$BUILD_IOS" = true ] && [ "$SKIP_PODS" = false ]; then
    print_header "Step 3: Fresh CocoaPods Install (iOS)"

    cd "$EXAMPLE_DIR/ios"

    print_step "Removing Pods directory..."
    rm -rf Pods

    print_step "Removing Podfile.lock..."
    rm -f Podfile.lock

    print_step "Removing iOS build artifacts..."
    rm -rf build
    rm -rf "$EXAMPLE_DIR/build/ios"

    print_step "Cleaning Xcode derived data for this project..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

    print_success "iOS artifacts cleaned"
else
    if [ "$BUILD_IOS" = true ]; then
        print_warning "Skipping CocoaPods clean (--skip-pods)"
    fi
fi

# =============================================================================
# Step 4: Fresh pub get
# =============================================================================

print_header "Step 4: Fresh Pub Get"

cd "$PROJECT_ROOT"
print_step "Getting dependencies for main package..."
flutter pub get

cd "$EXAMPLE_DIR"
print_step "Getting dependencies for example app..."
flutter pub get

print_success "Dependencies installed"

# =============================================================================
# Step 5: Install CocoaPods (iOS)
# =============================================================================

if [ "$BUILD_IOS" = true ]; then
    print_header "Step 5: Installing CocoaPods (iOS)"

    cd "$EXAMPLE_DIR/ios"

    print_step "Running pod install..."
    pod install --repo-update

    print_success "CocoaPods installed"
fi

# =============================================================================
# Step 6: Build and Install on Android
# =============================================================================

if [ "$BUILD_ANDROID" = true ]; then
    print_header "Step 6: Building and Installing on Android"

    cd "$EXAMPLE_DIR"

    # Check for connected Android devices
    if ! adb devices | grep -q "device$"; then
        print_warning "No Android device/emulator connected"
        print_step "Starting Android emulator..."

        # Try to start an emulator if available
        EMULATOR=$(emulator -list-avds 2>/dev/null | head -1)
        if [ -n "$EMULATOR" ]; then
            print_step "Starting emulator: $EMULATOR"
            emulator -avd "$EMULATOR" -no-snapshot-load &

            print_step "Waiting for emulator to boot..."
            adb wait-for-device
            sleep 30  # Give it time to fully boot
        else
            print_error "No Android emulator available. Please start one manually."
            BUILD_ANDROID=false
        fi
    fi

    if [ "$BUILD_ANDROID" = true ]; then
        # Determine target device
        if [ -n "$TARGET_DEVICE" ]; then
            ANDROID_DEVICE="$TARGET_DEVICE"
        else
            ANDROID_DEVICE=$(adb devices | grep "device$" | head -1 | cut -f1)
        fi

        if [ -n "$ANDROID_DEVICE" ]; then
            print_step "Target Android device: $ANDROID_DEVICE"
            print_step "Building and installing Android app..."

            flutter build apk --debug
            flutter install -d "$ANDROID_DEVICE" --debug

            print_success "Android app installed on $ANDROID_DEVICE"

            # Launch the app
            print_step "Launching Android app..."
            adb -s "$ANDROID_DEVICE" shell am start -n com.example.leela_chess_zero_example/.MainActivity

            print_success "Android app launched"
        else
            print_error "Could not find Android device"
        fi
    fi
fi

# =============================================================================
# Step 7: Build and Install on iOS
# =============================================================================

if [ "$BUILD_IOS" = true ]; then
    print_header "Step 7: Building and Installing on iOS"

    cd "$EXAMPLE_DIR"

    # Check for iOS simulators or devices
    if [ -n "$TARGET_DEVICE" ]; then
        IOS_DEVICE="$TARGET_DEVICE"
    else
        # Try to find a booted simulator first
        IOS_DEVICE=$(xcrun simctl list devices booted -j 2>/dev/null | grep -o '"udid" : "[^"]*"' | head -1 | cut -d'"' -f4)

        if [ -z "$IOS_DEVICE" ]; then
            print_step "No booted iOS simulator found. Starting one..."

            # Find an available iPhone simulator
            SIMULATOR=$(xcrun simctl list devices available -j | grep -A1 '"name" : "iPhone' | grep '"udid"' | head -1 | grep -o '"udid" : "[^"]*"' | cut -d'"' -f4)

            if [ -n "$SIMULATOR" ]; then
                print_step "Booting simulator: $SIMULATOR"
                xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
                open -a Simulator
                sleep 10  # Wait for simulator to boot
                IOS_DEVICE="$SIMULATOR"
            fi
        fi
    fi

    if [ -n "$IOS_DEVICE" ]; then
        print_step "Target iOS device: $IOS_DEVICE"
        print_step "Building and installing iOS app..."

        flutter build ios --debug --simulator
        flutter install -d "$IOS_DEVICE" --debug

        print_success "iOS app installed on $IOS_DEVICE"

        # Launch the app
        print_step "Launching iOS app..."
        xcrun simctl launch "$IOS_DEVICE" com.example.leelaChessZeroExample 2>/dev/null || \
            xcrun simctl launch "$IOS_DEVICE" com.example.leela-chess-zero-example 2>/dev/null || \
            print_warning "Could not auto-launch iOS app. Please launch manually."

        print_success "iOS app launched"
    else
        print_error "Could not find iOS device/simulator"
    fi
fi

# =============================================================================
# Summary
# =============================================================================

print_header "Build Complete!"

echo -e "${GREEN}Summary:${NC}"
if [ "$BUILD_ANDROID" = true ]; then
    echo -e "  ${GREEN}✓${NC} Android: Built and installed"
fi
if [ "$BUILD_IOS" = true ]; then
    echo -e "  ${GREEN}✓${NC} iOS: Built and installed"
fi

echo ""
echo -e "${CYAN}To view logs:${NC}"
if [ "$BUILD_ANDROID" = true ]; then
    echo -e "  Android: ${YELLOW}adb logcat -s LC0,LC0_FFI,flutter${NC}"
fi
if [ "$BUILD_IOS" = true ]; then
    echo -e "  iOS:     ${YELLOW}flutter logs${NC}"
fi

echo ""
print_success "Done!"

