#!/bin/bash
# Build script that includes companion dylibs
set -e

cd "$(dirname "$0")"

echo "=== Building TitaniumLiteRTLM module ==="
ti build -p ios --build-only

echo ""
echo "=== Copying companion dylibs ==="
bash post_build_fix_dylibs.sh

echo ""
echo "=== Patching module ZIP with dylibs ==="
TMPDIR=$(mktemp -d)
unzip -q dist/de.marcbender.litertlm-iphone-1.0.0.zip -d "$TMPDIR"

# Copy dylibs from build to extracted ZIP
for PLATFORM in ios-arm64-simulator ios-arm64; do
    FRAMEWORK_DIR="$TMPDIR/modules/iphone/de.marcbender.litertlm/1.0.0/DeMarcbenderLitertlm.xcframework/$PLATFORM/DeMarcbenderLitertlm.framework"
    BUILD_DIR="build/DeMarcbenderLitertlm.xcframework/$PLATFORM/DeMarcbenderLitertlm.framework"
    
    if [ -d "$FRAMEWORK_DIR" ] && [ -d "$BUILD_DIR" ]; then
        for DYLIB in "$BUILD_DIR"/*.dylib; do
            if [ -f "$DYLIB" ]; then
                cp "$DYLIB" "$FRAMEWORK_DIR/"
                echo "  Copied $(basename $DYLIB) to $PLATFORM"
            fi
        done
    fi
done

# Recreate ZIP
cd "$TMPDIR"
zip -q -r "$PWD/temp.zip" modules/iphone/de.marcbender.litertlm/
cp "$PWD/temp.zip" /Users/marcbender/TitaniumLiteRTLM/ios/dist/de.marcbender.litertlm-iphone-1.0.0.zip
rm -f "$PWD/temp.zip"
cd - > /dev/null
rm -rf "$TMPDIR"

echo ""
echo "=== Build complete ==="
echo "Module ZIP: dist/de.marcbender.litertlm-iphone-1.0.0.zip"
