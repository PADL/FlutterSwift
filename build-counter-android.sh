#!/bin/bash

set -Eeu

pwd=`pwd`

unset CLASSPATH
unset JAVA_HOME
unset JAVA_INCLUDE_PATH

FLUTTER_SWIFT_JVM=true
export FLUTTER_SWIFT_JVM

NDK_VERS=24

SWIFT_VERS=6.0.2
SWIFT_SDK="$(swift sdk list|grep android)"
SWIFT_SDK_SYSROOT="${HOME}/.swiftpm/swift-sdks/${SWIFT_SDK}.artifactbundle/swift-${SWIFT_VERS}-release-android-${NDK_VERS}-sdk/android-27c-sysroot"

HOST_JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home"
TARGET_JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"

TOOLCHAINS="/Library/Developer/Toolchains/swift-${SWIFT_VERS}-RELEASE.xctoolchain"
export TOOLCHAINS

TRIPLE="aarch64-unknown-linux-android${NDK_VERS}"
export TRIPLE

# Path to Flutter SDK
FLUTTER_SDK=/opt/flutter
export FLUTTER_SDK

PATH=$PATH:${FLUTTER_SDK}/bin
export PATH

# Package name of the build target Flutter app
export APP_PACKAGE_NAME=counter
export SOURCE_DIR=${pwd}/Examples/${APP_PACKAGE_NAME}

# Build the compiler tools for the host platform

export JAVA_HOME=${HOST_JAVA_HOME}
export JAVA_INCLUDE_PATH=${HOST_JAVA_HOME}/include

"${TOOLCHAINS}/usr/bin/swift" build --product Java2Swift
"${TOOLCHAINS}/usr/bin/swift" build --product JavaCompilerPlugin

export JAVA_HOME=${TARGET_JAVA_HOME}
export JAVA_INCLUDE_PATH="${SWIFT_SDK_SYSROOT}/usr/include"

CLASSPATH="${FLUTTER_SDK}/bin/cache/artifacts/engine/android-arm64/flutter.jar:${HOME}/Library/Android/sdk/platforms/android-34/android.jar"
export CLASSPATH

"${TOOLCHAINS}/usr/bin/swift" build --swift-sdk ${TRIPLE} --product FlutterSwift -j 1
#"${TOOLCHAINS}/usr/bin/swift" build --swift-sdk ${TRIPLE} --product Counter -j 1

# The build data.
#export RESULT_DIR=build/elinux/arm64
#export BUILD_MODE=debug

#pushd ${SOURCE_DIR}

#mkdir -p .dart_tool/flutter_build/flutter-embedded-linux
#mkdir -p ${RESULT_DIR}/${BUILD_MODE}/bundle/lib/
#mkdir -p ${RESULT_DIR}/${BUILD_MODE}/bundle/data/

#cd Sources/JavaKitAndroidExample

#APP_LIBS=app/libs/arm64-v8a

#mkdir -p ${APP_LIBS}
#cp ../../.build/${TRIPLE}/debug/libJavaKitExample.so ${APP_LIBS}
#cp ${SWIFT_SDK_SYSROOT}/usr/lib/aarch64-linux-android/${NDK_VERS}/lib*.so ${APP_LIBS}
#rm -f ${APP_LIBS}/lib{c,dl,log,m,z}.so

#./gradlew assembleDebug
#./gradlew installDebug

#popd
