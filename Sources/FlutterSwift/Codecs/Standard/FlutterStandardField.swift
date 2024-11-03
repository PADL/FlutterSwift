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

public enum FlutterStandardField: UInt8, Codable, Sendable {
  case `nil`
  case `true`
  case `false`
  case int32
  case int64
  case intHex
  case float64
  case string
  case uint8Data
  case int32Data
  case int64Data
  case float64Data
  case list
  case map
  case float32Data
}
