#!/bin/bash
pwd=`pwd`
bundle="${pwd}/Examples/counter/build/elinux/arm64/debug/bundle"

if [ "xFLUTTER_SWIFT_BACKEND" == "xwayland" ]; then
  .build/debug/Counter ${bundle}
else
  export FLUTTER_DRM_DEVICE=/dev/dri/card0
  sudo .build/debug/Counter ${bundle}
fi
