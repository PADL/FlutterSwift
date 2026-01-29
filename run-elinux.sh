#!/bin/bash

source build-defaults.inc

export LD_LIBRARY_PATH="${BUNDLE_DIR}/lib"
export LD_PRELOAD="${LD_LIBRARY_PATH}/libflutter_engine.so"

.build/$FLUTTER_SWIFT_BUILD_CONFIG/counter ${BUNDLE_DIR}
