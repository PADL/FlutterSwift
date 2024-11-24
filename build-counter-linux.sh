#!/bin/bash

set -Eeu

PWD=`pwd`

# Path to Flutter SDK
export FLUTTER_SDK=/opt/flutter-elinux/flutter

export PATH=$PATH:${FLUTTER_SDK}/bin

# Package name of the build target Flutter app
export APP_PACKAGE_NAME=counter
export SOURCE_DIR=${PWD}/Examples/${APP_PACKAGE_NAME}

ARCH=`arch`

if [ "X${ARCH}" == "Xaarch64" ]; then
	ARCH=arm64
elif [ "X${ARCH}" == "Xx86_64" ]; then
	ARCH=x64
fi

ARCH="linux-${ARCH}"

# The build data.
export RESULT_DIR=build/elinux/arm64
export BUILD_MODE=debug

pushd ${SOURCE_DIR}

mkdir -p .dart_tool/flutter_build/flutter-embedded-linux
mkdir -p ${RESULT_DIR}/${BUILD_MODE}/bundle/lib/
mkdir -p ${RESULT_DIR}/${BUILD_MODE}/bundle/data/

# Build Flutter assets.
${FLUTTER_SDK}/../bin/flutter-elinux build bundle --asset-dir=${RESULT_DIR}/${BUILD_MODE}/bundle/data/flutter_assets
cp ${FLUTTER_SDK}/bin/cache/artifacts/engine/${ARCH}/icudtl.dat \
   ${RESULT_DIR}/${BUILD_MODE}/bundle/data/

# Build kernel_snapshot.
${FLUTTER_SDK}/bin/cache/dart-sdk/bin/dartaotruntime \
  --verbose \
  --disable-dart-dev ${FLUTTER_SDK}/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot \
  --sdk-root ${FLUTTER_SDK}/bin/cache/artifacts/engine/common/flutter_patched_sdk_product/ \
  --target=flutter \
  --no-print-incremental-dependencies \
  -Ddart.vm.profile=false \
  -Ddart.vm.product=true \
  --aot \
  --tfa \
  --target-os linux \
  --packages .dart_tool/package_config.json \
  --output-dill .dart_tool/flutter_build/flutter-embedded-linux/app.dill \
  --depfile .dart_tool/flutter_build/flutter-embedded-linux/kernel_snapshot.d \
  --verbosity=error \
  package:${APP_PACKAGE_NAME}/main.dart

# Build AOT image.
${FLUTTER_SDK}/bin/cache/artifacts/engine/${ARCH}/gen_snapshot \
  --deterministic \
  --snapshot_kind=app-aot-elf \
  --elf=.dart_tool/flutter_build/flutter-embedded-linux/app.so \
  --strip \
  .dart_tool/flutter_build/flutter-embedded-linux/app.dill

cp .dart_tool/flutter_build/flutter-embedded-linux/app.so ${RESULT_DIR}/${BUILD_MODE}/bundle/lib/libapp.so

popd

swift build

