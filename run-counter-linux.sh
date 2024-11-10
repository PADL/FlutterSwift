#!/bin/bash
pwd=`pwd`
bundle="${pwd}/Examples/counter/build/elinux/arm64/debug/bundle"

if [ "x$FLUTTER_SWIFT_BACKEND" == "xwayland" ]; then
  .build/debug/counter ${bundle}
else
  export FLUTTER_DRM_DEVICE=/dev/dri/card0
  sudo .build/debug/counter ${bundle}
fi
