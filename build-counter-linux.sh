#!/bin/bash

set -Eeu

# Path to Flutter SDK
export FLUTTER_ROOT=/opt/flutter-elinux
export FLUTTER_SDK=${FLUTTER_ROOT}/flutter
export FLUTTER_CACHE_ENGINEDIR=${FLUTTER_SDK}/bin/cache/artifacts/engine
export DART_CACHE_BINDIR=${FLUTTER_SDK}/bin/cache/dart-sdk/bin

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

# The build data.
export RESULT_DIR=build/elinux/${ARCH}
export BUILD_MODE=debug
export BUNDLE_DIR=${RESULT_DIR}/${BUILD_MODE}/bundle

pushd ${SOURCE_DIR}
rm -rf ${BUNDLE_DIR}
mkdir -p ${BUNDLE_DIR}/lib/
mkdir -p ${BUNDLE_DIR}/data/

mkdir -p .dart_tool/flutter_build/flutter-embedded-linux

# Build Flutter assets.
echo "Building Flutter assets..."
${FLUTTER_ROOT}/bin/flutter-elinux build bundle --asset-dir=${BUNDLE_DIR}/data/flutter_assets

cp ${FLUTTER_CACHE_ENGINEDIR}/linux-${ARCH}/icudtl.dat ${BUNDLE_DIR}/data/

# Build kernel_snapshot.
echo "Building kernel snapshot..."
${DART_CACHE_BINDIR}/dartaotruntime \
  --verbose \
  --disable-dart-dev ${DART_CACHE_BINDIR}/snapshots/frontend_server_aot.dart.snapshot \
  --sdk-root ${FLUTTER_CACHE_ENGINEDIR}/common/flutter_patched_sdk_product/ \
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
echo "Building AOT image... "
${FLUTTER_CACHE_ENGINEDIR}/linux-${ARCH}-release/gen_snapshot \
  --deterministic \
  --snapshot_kind=app-aot-elf \
  --elf=.dart_tool/flutter_build/flutter-embedded-linux/app.so \
  --strip \
  .dart_tool/flutter_build/flutter-embedded-linux/app.dill

cp .dart_tool/flutter_build/flutter-embedded-linux/app.so ${BUNDLE_DIR}/lib/libapp.so
ls -al ${BUNDLE_DIR}/lib/libapp.so

# remove these artefacts to ensure we don't accidentally start in JIT mode

if [ "X${BUILD_MODE}" == "Xrelease" ]; then
  rm -rf ${BUNDLE_DIR}/data/flutter_assets/kernel_blob.bin
  rm -rf ${BUNDLE_DIR}/data/flutter_assets/isolate_snapshot_data
  rm -rf ${BUNDLE_DIR}/data/flutter_assets/vm_snapshot_data
fi

echo "Copying Flutter engine to bundle lib directory..."
cp ${FLUTTER_CACHE_ENGINEDIR}/elinux-${ARCH}-${BUILD_MODE}/libflutter_engine.so ${BUNDLE_DIR}/lib/
