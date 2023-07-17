#!/bin/sh
export LD_LIBRARY_PATH=/opt/elinux/lib:$LD_LIBRARY_PATH
swift test -Xswiftc -cxx-interoperability-mode=default
