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

public protocol FlutterPlatformView {
  var registrar: FlutterPluginRegistrar { get }
  var viewId: Int { get }
  var textureId: Int { get set }
  var isFocused: Bool { get set }

  func dispose()
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
  case touchMethod
  case acceptGesture
  case rejectGesture
  case enter
  case exit
}

enum FlutterPlatformViewKey: String, CaseIterable {
  case viewType
  case id
  case width
  case height
  case params
}

public final class FlutterPlatformViewsPlugin: FlutterPlugin {
  var viewFactories = [String: FlutterPlatformViewFactory]()
  var platformViews = [Int: FlutterPlatformView]()
  var currentViewId: Int = -1

  public required init() {}

  public func handleMethod(call: FlutterMethodCall<AnyFlutterStandardCodable>) throws
    -> AnyFlutterStandardCodable?
  {
    guard let methodName = FlutterPlatformViewMethod(rawValue: call.method) else {
      throw FlutterSwiftError.methodNotImplemented
    }

    switch methodName {
    case .create:
      return try create(call.arguments)
    case .dispose:
      return try dispose(call.arguments)
    default:
      throw FlutterSwiftError.methodNotImplemented
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {}

  public func register(viewType: String, factory: FlutterPlatformViewFactory) {
    guard !viewFactories.keys.contains(viewType) else {
      debugPrint("Platform view factory for \(viewType) is already registered")
      return
    }
    viewFactories[viewType] = factory
  }

  func create(_ arguments: AnyFlutterStandardCodable?) throws -> AnyFlutterStandardCodable? {
    guard let arguments = arguments?.value as? [String: Any] else {
      throw FlutterError(code: "Couldn't parse arguments")
    }

    guard let viewType = arguments[FlutterPlatformViewKey.viewType.rawValue] as? String else {
      throw FlutterError(code: "Couldn't find the view type in the arguments")
    }

    guard let viewId = arguments[FlutterPlatformViewKey.id.rawValue] as? Int else {
      throw FlutterError(code: "Couldn't find the view id in the arguments")
    }

    guard let width = arguments[FlutterPlatformViewKey.width.rawValue] as? Double else {
      throw FlutterError(code: "Couldn't find the width in the arguments")
    }

    guard let height = arguments[FlutterPlatformViewKey.height.rawValue] as? Double else {
      throw FlutterError(code: "Couldn't find the height in the arguments")
    }

    guard let factory = viewFactories[viewType] else {
      throw FlutterError(code: "Couldn't find the view type")
    }

    let params = arguments[FlutterPlatformViewKey.params.rawValue] as? [UInt8]
    guard let view = factory.create(
      viewId: viewId,
      width: width,
      height: height,
      params: params ?? []
    ) else {
      throw FlutterError(code: "Failed to create a platform view")
    }

    platformViews[viewId] = view
    if var currentView = platformViews[currentViewId] {
      currentView.isFocused = false
    }
    currentViewId = viewId
    return nil
  }

  func dispose(_ arguments: AnyFlutterStandardCodable?) throws -> AnyFlutterStandardCodable? {
    guard let arguments = arguments?.value as? [String: Any] else {
      throw FlutterError(code: "Couldn't parse arguments")
    }

    guard let viewId = arguments[FlutterPlatformViewKey.id.rawValue] as? Int else {
      throw FlutterError(code: "Couldn't find the view id in the arguments")
    }

    guard let platformView = platformViews[viewId] else {
      throw FlutterError(code: "Couldn't find the view id in the arguments")
    }

    platformView.dispose()
    return nil
  }
}

#endif
