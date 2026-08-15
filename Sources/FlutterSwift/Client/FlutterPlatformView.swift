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

#if os(Linux) && canImport(Glibc)
@_implementationOnly
import CxxFlutterSwift

// A class, mirroring the embedder's `FlutterDesktopPlatformView*`: the plugin
// keeps these in a registry and mutates them in place, which a value type
// silently would not do.
public protocol FlutterPlatformView: AnyObject {
  var registrar: FlutterPluginRegistrar { get }
  var viewId: Int { get }
  var textureId: Int { get set }
  var isFocused: Bool { get set }

  func dispose()
  func clearFocus()
  func resize(width: Double, height: Double)
  func touch(deviceId: Int, eventType: Int, x: Double, y: Double)
  func offset(top: Double, left: Double)
}

public protocol FlutterPlatformViewFactory {
  var registrar: FlutterPluginRegistrar { get }

  func create(viewId: Int, width: Double, height: Double, params: [UInt8])
    -> FlutterPlatformView?
}

enum FlutterPlatformViewMethod: String {
  case create
  case dispose
  case resize
  case setDirection
  case clearFocus
  case touch
  case acceptGesture
  case rejectGesture
  case enter
  case exit
  case offset
}

enum FlutterPlatformViewKey: String, CaseIterable {
  case viewType
  case id
  case width
  case height
  case params
  case top
  case left
}

// The arguments arrive already parsed, so read them off the enum directly:
// `value(as:)` bridges via JSON, which is far too costly for a per-touch path.
private extension AnyFlutterStandardCodable {
  subscript(key: FlutterPlatformViewKey) -> AnyFlutterStandardCodable? {
    guard case let .map(map) = self else { return nil }
    return map[.string(key.rawValue)]
  }

  var intValue: Int? {
    switch self {
    case let .int32(value): Int(value)
    case let .int64(value): Int(value)
    default: nil
    }
  }

  var doubleValue: Double? {
    guard case let .float64(value) = self else { return nil }
    return value
  }

  var stringValue: String? {
    guard case let .string(value) = self else { return nil }
    return value
  }

  var listValue: [AnyFlutterStandardCodable]? {
    guard case let .list(value) = self else { return nil }
    return value
  }

  var uint8DataValue: [UInt8]? {
    guard case let .uint8Data(value) = self else { return nil }
    return value
  }
}

// Owns the `flutter/platform_views` channel, in place of the embedder's own
// PlatformViewsPlugin: registering here displaces that handler, so this must
// cover every method it implements.
@FlutterPlatformThreadActor
public final class FlutterPlatformViewsPlugin: FlutterPlugin {
  private var viewFactories = [String: FlutterPlatformViewFactory]()
  private var platformViews = [Int: FlutterPlatformView]()
  private var currentViewId: Int = -1

  public nonisolated init() {}

  public func handleMethod(call: FlutterMethodCall<AnyFlutterStandardCodable>) throws
    -> AnyFlutterStandardCodable?
  {
    guard let methodName = FlutterPlatformViewMethod(rawValue: call.method) else {
      throw FlutterSwiftError.methodNotImplemented
    }
    let arguments = call.arguments ?? .nil

    switch methodName {
    case .create:
      return try create(arguments)
    case .dispose:
      return try dispose(arguments)
    case .resize:
      return try resize(arguments)
    case .clearFocus:
      return try clearFocus(arguments)
    case .touch:
      return try touch(arguments)
    case .offset:
      return try offset(arguments)
    case .setDirection, .acceptGesture, .rejectGesture, .enter, .exit:
      // not implemented by the embedder either
      throw FlutterSwiftError.methodNotImplemented
    }
  }

  public nonisolated func detachFromEngine(for registrar: FlutterPluginRegistrar) {}

  public func register(viewType: String, factory: FlutterPlatformViewFactory) {
    guard !viewFactories.keys.contains(viewType) else {
      debugPrint("Platform view factory for \(viewType) is already registered")
      return
    }
    viewFactories[viewType] = factory
  }

  private func view(for arguments: AnyFlutterStandardCodable) throws -> FlutterPlatformView {
    guard let viewId = arguments[.id]?.intValue else {
      throw FlutterError(code: "Couldn't find the view id in the arguments")
    }
    guard let platformView = platformViews[viewId] else {
      throw FlutterError(code: "Couldn't find the view id in the arguments")
    }
    return platformView
  }

  func create(_ arguments: AnyFlutterStandardCodable) throws -> AnyFlutterStandardCodable? {
    guard let viewType = arguments[.viewType]?.stringValue else {
      throw FlutterError(code: "Couldn't find the view type in the arguments")
    }

    guard let viewId = arguments[.id]?.intValue else {
      throw FlutterError(code: "Couldn't find the view id in the arguments")
    }

    guard let width = arguments[.width]?.doubleValue else {
      throw FlutterError(code: "Couldn't find the width in the arguments")
    }

    guard let height = arguments[.height]?.doubleValue else {
      throw FlutterError(code: "Couldn't find the height in the arguments")
    }

    guard let factory = viewFactories[viewType] else {
      throw FlutterError(code: "Couldn't find the view type")
    }

    guard let view = factory.create(
      viewId: viewId,
      width: width,
      height: height,
      params: arguments[.params]?.uint8DataValue ?? []
    ) else {
      throw FlutterError(code: "Failed to create a platform view")
    }

    platformViews[viewId] = view
    platformViews[currentViewId]?.isFocused = false
    currentViewId = viewId
    // the texture the view rendered into, which Dart composites the widget from
    return .int64(Int64(view.textureId))
  }

  func dispose(_ arguments: AnyFlutterStandardCodable) throws -> AnyFlutterStandardCodable? {
    let platformView = try view(for: arguments)
    platformView.dispose()
    platformViews.removeValue(forKey: platformView.viewId)
    return nil
  }

  func resize(_ arguments: AnyFlutterStandardCodable) throws -> AnyFlutterStandardCodable? {
    guard let width = arguments[.width]?.doubleValue, width > 0,
          let height = arguments[.height]?.doubleValue, height > 0
    else {
      throw FlutterError(code: "width and height must be greater than zero")
    }
    try view(for: arguments).resize(width: width, height: height)
    return arguments
  }

  func clearFocus(_ arguments: AnyFlutterStandardCodable) throws -> AnyFlutterStandardCodable? {
    let platformView = try view(for: arguments)
    platformView.isFocused = false
    platformView.clearFocus()
    return nil
  }

  func offset(_ arguments: AnyFlutterStandardCodable) throws -> AnyFlutterStandardCodable? {
    guard let top = arguments[.top]?.doubleValue,
          let left = arguments[.left]?.doubleValue
    else {
      throw FlutterError(code: "Couldn't find the offset in the arguments")
    }
    try view(for: arguments).offset(top: top, left: left)
    return nil
  }

  // Unlike the others this arrives as a positional list — a raw Android
  // MotionEvent — so the indices below match the embedder's.
  func touch(_ arguments: AnyFlutterStandardCodable) throws -> AnyFlutterStandardCodable? {
    guard let event = arguments.listValue, event.count > 11,
          let viewId = event[0].intValue,
          let eventType = event[3].intValue,
          let deviceId = event[11].intValue
    else {
      throw FlutterError(code: "Couldn't parse the touch event in the arguments")
    }

    guard let pointerCoords = event[6].listValue?.first?.listValue,
          pointerCoords.count > 8,
          let x = pointerCoords[7].doubleValue,
          let y = pointerCoords[8].doubleValue
    else {
      throw FlutterError(code: "Couldn't find the pointer_coords in the arguments")
    }

    guard let platformView = platformViews[viewId] else {
      throw FlutterError(code: "Couldn't find the view id in the arguments")
    }

    platformView.touch(deviceId: deviceId, eventType: eventType, x: x, y: y)
    return nil
  }
}

#endif
