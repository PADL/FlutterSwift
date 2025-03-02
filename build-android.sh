#!/bin/bash

set -Eeu

pwd=$(pwd)

# Package name of the build target Flutter app
APP_PACKAGE_SOURCE=${1-${pwd}/Examples/counter}
echo "Building FlutterAndroid JNI library for ${APP_PACKAGE_SOURCE}..."

unset CLASSPATH
unset JAVA_HOME
unset JAVA_INCLUDE_PATH

FLUTTER_SWIFT_JVM=true
export FLUTTER_SWIFT_JVM

NDK_VERS=24

SWIFT_VERS=6.0.3
SWIFT_SDK="$(swift sdk list|grep android|tail -1)"
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

export APP_PACKAGE_NAME=$(basename ${APP_PACKAGE_SOURCE})

# Build the compiler tools for the host platform

export JAVA_HOME=${HOST_JAVA_HOME}
export JAVA_INCLUDE_PATH=${HOST_JAVA_HOME}/include

swift build -Xswiftc -Xfrontend -Xswiftc -disable-round-trip-debug-types --toolchain ${TOOLCHAINS} --product Java2Swift
swift build -Xswiftc -Xfrontend -Xswiftc -disable-round-trip-debug-types --toolchain ${TOOLCHAINS} --product JavaCompilerPlugin

export JAVA_HOME=${TARGET_JAVA_HOME}
export JAVA_INCLUDE_PATH="${SWIFT_SDK_SYSROOT}/usr/include"

FLUTTER_CLASSPATH="${FLUTTER_SDK}/bin/cache/artifacts/engine/android-arm64/flutter.jar"
FLUTTER_CLASSPATH_REF=".build/plugins/outputs/flutterswift/FlutterAndroid/destination/Java2SwiftPlugin/Flutter.swift-java.classpath"
echo -n ${FLUTTER_CLASSPATH} > ${FLUTTER_CLASSPATH_REF}
export CLASSPATH=${FLUTTER_CLASSPATH}

swift build -Xswiftc -Xfrontend -Xswiftc -disable-round-trip-debug-types --toolchain ${TOOLCHAINS} --swift-sdk ${TRIPLE} --product FlutterSwift

PLUGINS_ROOT=.build/plugins/outputs/flutterswift
JAVACOMPILER_SUFFIX=destination/JavaCompilerPlugin/Java
SWIFT_JAR="${APP_PACKAGE_SOURCE}/android/app/libs/flutterswift.jar"

rm -f ${SWIFT_JAR}
(cd ${PLUGINS_ROOT}/FlutterAndroid/${JAVACOMPILER_SUFFIX}; jar cf ${SWIFT_JAR} .)

CLASSPATH="${CLASSPATH}:${SWIFT_JAR}"
export CLASSPATH

swift build -Xswiftc -Xfrontend -Xswiftc -disable-round-trip-debug-types --toolchain ${TOOLCHAINS} --swift-sdk ${TRIPLE} --product ${APP_PACKAGE_NAME}

cd ${APP_PACKAGE_SOURCE}

APP_LIBS=android/app/libs/arm64-v8a
export JAVA_HOME=${TARGET_JAVA_HOME}

mkdir -p ${APP_LIBS}
cp ${pwd}/.build/${TRIPLE}/debug/lib${APP_PACKAGE_NAME}.so ${APP_LIBS}
cp ${SWIFT_SDK_SYSROOT}/usr/lib/aarch64-linux-android/${NDK_VERS}/lib*.so ${APP_LIBS}
rm -f ${APP_LIBS}/lib{c,dl,log,m,z}.so

unset CLASSPATH
${FLUTTER_SDK}/bin/flutter build apk --debug
