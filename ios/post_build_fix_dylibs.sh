#!/bin/bash
# Post-build script to copy and sign CLiteRTLM companion dylibs
# Run after `ti build -p ios --build-only`

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
XCFRAMEWORK="$PROJECT_DIR/build/DeMarcbenderLitertlm.xcframework"
PLATFORM_XCFRAMEWORK="$PROJECT_DIR/platform/LiteRTLM.xcframework"

echo "=== Post-build: Fixing CLiteRTLM companion dylibs ==="

# Simulator
SIM_DIR="$XCFRAMEWORK/ios-arm64-simulator/DeMarcbenderLitertlm.framework"
SIM_DYLIB="$PLATFORM_XCFRAMEWORK/ios-arm64-simulator/CLiteRTLM.framework/libLiteRtMetalAccelerator.dylib"

if [ -d "$SIM_DIR" ] && [ -f "$SIM_DYLIB" ]; then
    echo "Copying simulator dylib..."
    cp "$SIM_DYLIB" "$SIM_DIR/"
    codesign --force --sign "-" "$SIM_DIR/libLiteRtMetalAccelerator.dylib"
    echo "Simulator dylib signed."
else
    echo "WARNING: Simulator dylib not found, skipping."
fi

# Device
DEVICE_DIR="$XCFRAMEWORK/ios-arm64/DeMarcbenderLitertlm.framework"
DEVICE_DYLIB="$PLATFORM_XCFRAMEWORK/ios-arm64/CLiteRTLM.framework/libLiteRtMetalAccelerator.dylib"
DEVICE_DYLIB2="$PLATFORM_XCFRAMEWORK/ios-arm64/CLiteRTLM.framework/libGemmaModelConstraintProvider.dylib"

if [ -d "$DEVICE_DIR" ]; then
    if [ -f "$DEVICE_DYLIB" ]; then
        echo "Copying device dylib (Metal)..."
        cp "$DEVICE_DYLIB" "$DEVICE_DIR/"
        codesign --force --sign "-" "$DEVICE_DIR/libLiteRtMetalAccelerator.dylib"
    fi
    if [ -f "$DEVICE_DYLIB2" ]; then
        echo "Copying device dylib (Gemma)..."
        cp "$DEVICE_DYLIB2" "$DEVICE_DIR/"
        codesign --force --sign "-" "$DEVICE_DIR/libGemmaModelConstraintProvider.dylib"
    fi
fi

echo "=== Done ==="
