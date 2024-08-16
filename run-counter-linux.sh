#!/bin/bash
pwd=`pwd`
FLUTTER_DRM_DEVICE=/dev/dri/card0
sudo .build/debug/Counter "${pwd}/Examples/counter/build/elinux/arm64/debug/bundle"
