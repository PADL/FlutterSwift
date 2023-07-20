#!/bin/sh
export LD_LIBRARY_PATH=/opt/flutter-elinux/lib:$LD_LIBRARY_PATH
swift test -Xswiftc -cxx-interoperability-mode=default
