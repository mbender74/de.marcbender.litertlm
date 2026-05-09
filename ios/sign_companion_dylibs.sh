#!/bin/bash
# Re-sign CLiteRTLM companion dylibs for Simulator
# This must run after the module build copies the framework to the app

FRAMEWORK_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/CLiteRTLM.framework"

if [ -d "$FRAMEWORK_PATH" ]; then
    for DYLIB in \
        "$FRAMEWORK_PATH/libGemmaModelConstraintProvider.dylib" \
        "$FRAMEWORK_PATH/libLiteRtMetalAccelerator.dylib"; do
        if [ -f "$DYLIB" ]; then
            echo "Re-signing $DYLIB"
            /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "$DYLIB"
        fi
    done
fi
