#!/bin/bash

source build-defaults.inc

# prefer the cached release versions to the ones that are included in the
# FlutterSwift zip (which are debug versions)

export LD_LIBRARY_PATH="${FLUTTER_CACHE_ENGINEDIR}/elinux-${ARCH}-${FLUTTER_SWIFT_BUILD_CONFIG}"
export LD_PRELOAD="${LD_LIBRARY_PATH}/libflutter_engine.so"

.build/$FLUTTER_SWIFT_BUILD_CONFIG/counter ${BUNDLE_DIR}
