//
// Copyright (c) 2023-2025 PADL Software Pty Ltd
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

let kChannelName = "flutter/platform_views"

public struct FlutterView {
  let view: flutter.FlutterELinuxView
  var platformViewsPluginRegistrar: FlutterPluginRegistrar?
  var platformViewsHandler: FlutterPlatformViewsPlugin?
  var viewController: FlutterViewController? {
    didSet {
      if let viewController {
        platformViewsPluginRegistrar = viewController.engine.registrar(for: kChannelName)
        platformViewsHandler = try? FlutterPlatformViewsPlugin
          .register(with: platformViewsPluginRegistrar!)
        viewController.view = self
      } else {
        platformViewsPluginRegistrar = nil
        platformViewsHandler = nil
      }
    }
  }

  init(_ view: flutter.FlutterELinuxView) {
    self.view = view
  }

  init(_ view: FlutterDesktopViewRef) {
    self.init(unsafeBitCast(view, to: flutter.FlutterELinuxView.self))
  }

  public func dispatchEvent() -> Bool {
    view.DispatchEvent()
  }

  public var frameRate: Int32 {
    view.GetFrameRate()
  }

  func createRenderSurface() -> Bool {
    view.CreateRenderSurface()
  }

  func destroyRenderSurface() {
    view.DestroyRenderSurface()
  }

  var rootSurfaceTransformation: FlutterTransformation {
    view.GetRootSurfaceTransformation()
  }

  func makeCurrent() -> Bool {
    view.MakeCurrent()
  }

  func clearCurrent() -> Bool {
    view.ClearCurrent()
  }

  func present() -> Bool {
    view.Present()
  }

  func presentWithInfo(_ info: UnsafePointer<FlutterPresentInfo>) -> Bool {
    view.PresentWithInfo(info)
  }

  func populateExistingDamage(fboID: Int, existingDamage: UnsafeMutablePointer<FlutterDamage>) {
    view.PopulateExistingDamage(fboID, existingDamage)
  }

  func getOnscreenFBO() -> UInt32 {
    view.GetOnscreenFBO()
  }

  func makeResourceCurrent() -> Bool {
    view.MakeResourceCurrent()
  }

  func sendInitialBounds() {
    view.SendInitialBounds()
  }

  func onWindowSizeChanged(widthPx: Int, heightPx: Int) {
    view.OnWindowSizeChanged(widthPx, heightPx)
  }

  func onPointerMove(xPx: Double, yPx: Double) {
    view.OnPointerMove(xPx, yPx)
  }

  func onPointerDown(xPx: Double, yPx: Double, button: FlutterPointerMouseButtons) {
    view.OnPointerDown(xPx, yPx, button)
  }

  func onPointerUp(xPx: Double, yPx: Double, button: FlutterPointerMouseButtons) {
    view.OnPointerUp(xPx, yPx, button)
  }

  func onPointerLeave() {
    view.OnPointerLeave()
  }

  func onTouchDown(time: UInt32, id: Int32, x: Double, y: Double) {
    view.OnTouchDown(time, id, x, y)
  }

  func onTouchUp(time: UInt32, id: Int32) {
    view.OnTouchUp(time, id)
  }

  func onTouchMotion(time: UInt32, id: Int32, x: Double, y: Double) {
    view.OnTouchMotion(time, id, x, y)
  }

  func onTouchCancel() {
    view.OnTouchCancel()
  }

  func onKeyMap(format: UInt32, fd: CInt, size: UInt32) {
    view.OnKeyMap(format, fd, size)
  }

  func onKeyModifiers(
    modsDepressed: UInt32,
    modsLatched: UInt32,
    modsLocked: UInt32,
    group: UInt32
  ) {
    view.OnKeyModifiers(modsDepressed, modsLatched, modsLocked, group)
  }

  func onKey(key: UInt32, pressed: Bool) {
    view.OnKey(key, pressed)
  }

  func onVirtualKey(codePoint: UInt32) {
    view.OnVirtualKey(codePoint)
  }

  func onVirtualSpecialKey(keyCode: UInt32) {
    view.OnVirtualSpecialKey(keyCode)
  }

  func onScroll(
    x: Double,
    y: Double,
    deltaX: Double,
    deltaY: Double,
    scrollOffsetMultiplier: CInt
  ) {
    view.OnScroll(x, y, deltaX, deltaY, scrollOffsetMultiplier)
  }

  func onVsync(lastFrameTimeNS: UInt64, vsyncIntervalTimeNS: UInt64) {
    view.OnVsync(lastFrameTimeNS, vsyncIntervalTimeNS)
  }

  func updateHighContrastEnabled(_ enabled: Bool) {
    view.UpdateHighContrastEnabled(enabled)
  }

  func updateTextScaleFactor(_ factor: Float) {
    view.UpdateTextScaleFactor(factor)
  }

  func updateDisplayInfo(refreshRate: Double, widthPx: Int, heightPx: Int, pixelRatio: Double) {
    view.UpdateDisplayInfo(refreshRate, widthPx, heightPx, pixelRatio)
  }
}
#endif
