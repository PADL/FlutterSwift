#!/bin/bash

if [ -z "${FLUTTER_SWIFT_BUILD_CONFIG}" ]; then
  FLUTTER_SWIFT_BUILD_CONFIG=debug
fi

export FLUTTER_SWIFT_BUILD_CONFIG

if [ -z "${FLUTTER_SWIFT_BACKEND}" ]; then
  FLUTTER_SWIFT_BACKEND=wayland
fi

export FLUTTER_SWIFT_BACKEND

if [ -z "${APP_PACKAGE_NAME}" ]; then
  APP_PACKAGE_NAME=counter
fi

export APP_PACKAGE_NAME

set -Eeu

pwd=`pwd`
ARCH=`arch`

if [ "X${ARCH}" == "Xaarch64" ]; then
  ARCH=arm64
elif [ "X${ARCH}" == "Xx86_64" ]; then
  ARCH=x64
fi

# Path to Flutter SDK
export FLUTTER_ROOT=/opt/flutter-elinux
export FLUTTER_SDK=${FLUTTER_ROOT}/flutter
export FLUTTER_CACHE_ENGINEDIR=${FLUTTER_SDK}/bin/cache/artifacts/engine
export DART_CACHE_BINDIR=${FLUTTER_SDK}/bin/cache/dart-sdk/bin
export PATH=$PATH:${FLUTTER_ROOT}/bin:${FLUTTER_SDK}/bin:/opt/swift/usr/bin

# Package name of the build target Flutter app
export SOURCE_DIR=${pwd}/Examples/${APP_PACKAGE_NAME}

# The build data.
export RESULT_DIR=${pwd}/build/elinux/${ARCH}
export BUNDLE_DIR=${RESULT_DIR}/${FLUTTER_SWIFT_BUILD_CONFIG}/bundle

if [ ! -d "${FLUTTER_CACHE_ENGINEDIR}" ]; then
  flutter-elinux precache
fi
