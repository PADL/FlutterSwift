This is a WIP as we don't have the Swift embedder finished yet. You'll need to compile to VM separately by building for another platform, and run with something like:

Note relative paths will be relative to the Swift build directory.

```
.build/debug/Counter $HOME/CVSRoot/padl/FlutterSwift/Examples/counter/build/elinux/arm64/debug/bundle
```

