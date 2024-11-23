#!/bin/bash

ENGINE_REVISION=$(cat .flutter-engine-revision)
ENGINE_URL="https://github.com/sony/flutter-embedded-linux/releases/download/${ENGINE_REVISION}"

tmp_dir=$(mktemp -d -t engine-XXXXXXXXXX)
artifact_dir="$tmp_dir/flutter-engine.artifactbundle"

mkdir -p "$artifact_dir"
cp info.json.in "$artifact_dir/info.json"
pushd "$artifact_dir/" >/dev/null

for platform in arm64-debug x64-debug
do
    mkdir "elinux-$platform"
    cd "elinux-$platform"
    wget "$ENGINE_URL/elinux-$platform.zip"
    unzip "elinux-$platform.zip"
    rm -f libflutter_elinux_*.so
    rm -f *.zip
    cd ..
done

cd ..
zip -r flutter-engine.artifactbundle.zip flutter-engine.artifactbundle/*
popd >/dev/null

mv "$tmp_dir/flutter-engine.artifactbundle.zip" .
rm -rf $tmp_dir
