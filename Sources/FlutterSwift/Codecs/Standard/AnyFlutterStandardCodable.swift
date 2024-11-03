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

public indirect enum AnyFlutterStandardCodable: Hashable, Sendable {
  case `nil`
  case `true`
  case `false`
  case int32(Int32)
  case int64(Int64)
  case float64(Double)
  case string(String)
  case uint8Data([UInt8])
  case int32Data([Int32])
  case int64Data([Int64])
  case float64Data([Double])
  case list([AnyFlutterStandardCodable])
  case map([AnyFlutterStandardCodable: AnyFlutterStandardCodable])
  case float32Data([Float])
}
