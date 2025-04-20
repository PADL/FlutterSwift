#!/bin/bash

source build-defaults.inc

pushd ${SOURCE_DIR}
rm -rf ${BUNDLE_DIR}
mkdir -p ${BUNDLE_DIR}/lib/
mkdir -p ${BUNDLE_DIR}/data/

mkdir -p .dart_tool/flutter_build/flutter-embedded-linux

echo "-- Starting ${FLUTTER_SWIFT_BUILD_CONFIG} mode build of ${APP_PACKAGE_NAME} --"

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
if [ "X${FLUTTER_SWIFT_BUILD_CONFIG}" == "Xrelease" ]; then
  echo "Building AOT image..."
  ${FLUTTER_CACHE_ENGINEDIR}/linux-${ARCH}-release/gen_snapshot \
    --deterministic \
    --snapshot_kind=app-aot-elf \
    --elf=.dart_tool/flutter_build/flutter-embedded-linux/app.so \
    --strip \
    .dart_tool/flutter_build/flutter-embedded-linux/app.dill

  cp .dart_tool/flutter_build/flutter-embedded-linux/app.so ${BUNDLE_DIR}/lib/libapp.so
  ls -al ${BUNDLE_DIR}/lib/libapp.so

  # remove these artefacts to ensure we don't accidentally start in JIT mode
  echo "Removing JIT artifacts..."
  rm -rf ${BUNDLE_DIR}/data/flutter_assets/kernel_blob.bin
  rm -rf ${BUNDLE_DIR}/data/flutter_assets/isolate_snapshot_data
  rm -rf ${BUNDLE_DIR}/data/flutter_assets/vm_snapshot_data
fi

echo "Building Swift component..."
popd
swift build --configuration ${FLUTTER_SWIFT_BUILD_CONFIG}

echo "Copying Flutter engine to bundle lib directory..."
if [ -f ${FLUTTER_CACHE_ENGINEDIR}/elinux-${ARCH}-${FLUTTER_SWIFT_BUILD_CONFIG}/libflutter_engine.so ]; then
  cp ${FLUTTER_CACHE_ENGINEDIR}/elinux-${ARCH}-${FLUTTER_SWIFT_BUILD_CONFIG}/libflutter_engine.so ${BUNDLE_DIR}/lib/
else
  cp .build/artifacts/flutterswift/CFlutterEngine/flutter-engine.artifactbundle/elinux-${ARCH}-${FLUTTER_SWIFT_BUILD_CONFIG}/libflutter_engine.so ${BUNDLE_DIR}/lib/
fi

echo "Done!"
