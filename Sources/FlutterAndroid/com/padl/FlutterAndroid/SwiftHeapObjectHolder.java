//
// Copyright (c) 2023-2024 PADL Software Pty Ltd
//
// Licensed under the Apache License, Version 2.0 (the License);
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an 'AS IS' BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

package com.padl.FlutterAndroid;

import java.lang.ref.Cleaner;

class SwiftHeapObjectHolder implements AutoCloseable {
  private static final Cleaner cleaner = Cleaner.create();

  private final Cleaner.Cleanable _cleanable;
  public long _swiftHeapObject;

  public SwiftHeapObjectHolder(long heapObjectInt64Ptr) {
    final Runnable F = () -> SwiftHeapObjectHolder._releaseSwiftHeapObject(heapObjectInt64Ptr);
    SwiftHeapObjectHolder._retainSwiftHeapObject(heapObjectInt64Ptr);
    _cleanable = cleaner.register(this, F);
    _swiftHeapObject = heapObjectInt64Ptr;
  }

  @Override
  public void close() throws Exception {
    _swiftHeapObject = 0;
    _cleanable.clean();
  }

  static native void _retainSwiftHeapObject(long heapObjectInt64Ptr);
  static native void _releaseSwiftHeapObject(long heapObjectInt64Ptr);
}
