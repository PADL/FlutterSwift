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

public class SwiftHeapObjectHolder implements AutoCloseable {
  private static final Cleaner cleaner = Cleaner.create();

  private final Cleaner.Cleanable _cleanable;
  public long _swiftObject;

  public SwiftHeapObjectHolder(long swiftObject) {
    final Runnable F = () -> SwiftHeapObjectHolder._releaseSwiftObject(swiftObject);
    _cleanable = cleaner.register(this, F);
    _swiftObject = swiftObject;
  }

  @Override
  public void close() throws Exception {
    _swiftObject = 0;
    _cleanable.clean();
  }

  public static native void _releaseSwiftObject(long swiftObject);
}
