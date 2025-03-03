#!/bin/bash

source build-defaults.inc

if [ "x$FLUTTER_SWIFT_BACKEND" == "xwayland" ]; then
  .build/$FLUTTER_SWIFT_BUILD_CONFIG/counter ${BUNDLE_DIR}
else
  export FLUTTER_DRM_DEVICE=/dev/dri/card0
  sudo .build/$FLUTTER_SWIFT_BUILD_CONFIG/counter ${BUNDLE_DIR}
fi
