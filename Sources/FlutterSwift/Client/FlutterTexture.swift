//
// Copyright (c) 2025 PADL Software Pty Ltd
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
import Foundation

public enum FlutterPixelFormat {
  case none
  case rgba8888
  case bgra8888

  fileprivate var _desktopPixelFormat: FlutterDesktopPixelFormat {
    switch self {
    case .none: return kFlutterDesktopPixelFormatNone
    case .rgba8888: return kFlutterDesktopPixelFormatRGBA8888
    case .bgra8888: return kFlutterDesktopPixelFormatBGRA8888
    }
  }
}

@discardableResult
private func _retainAnyObject<T: AnyObject>(_ anyObject: T) -> UnsafeMutableRawPointer {
  Unmanaged.passRetained(anyObject).toOpaque()
}

private func _releaseAnyObject(_ anyObjectPtr: UnsafeMutableRawPointer?) {
  Unmanaged<AnyObject>.fromOpaque(anyObjectPtr!).release()
}

public class FlutterPixelBuffer {
  public var buffer: UnsafeMutablePointer<UInt8>
  public var width: Int
  public var height: Int

  private var _desktopPixelBuffer = FlutterDesktopPixelBuffer()

  public init(width: Int, height: Int) {
    buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
    buffer.initialize(repeating: 0, count: width * height)
    self.width = width
    self.height = height
  }

  deinit {
    buffer.deallocate()
  }

  fileprivate func getDesktopPixelBufferTextureConfig(
    width: Int,
    height: Int
  ) -> UnsafePointer<FlutterDesktopPixelBuffer> {
    _desktopPixelBuffer.buffer = UnsafePointer(buffer)
    _desktopPixelBuffer.width = self.width
    _desktopPixelBuffer.height = self.height
    _desktopPixelBuffer.release_context = _retainAnyObject(self)
    _desktopPixelBuffer.release_callback = _releaseAnyObject
    return withUnsafePointer(to: &_desktopPixelBuffer) { $0 }
  }
}

private func _getDesktopPixelBufferTextureConfigThunk(
  width: Int,
  height: Int,
  user_data: UnsafeMutableRawPointer?
) -> UnsafePointer<FlutterDesktopPixelBuffer>? {
  Unmanaged<FlutterPixelBuffer>.fromOpaque(user_data!).takeUnretainedValue()
    .getDesktopPixelBufferTextureConfig(
      width: width,
      height: height
    )
}

public class FlutterEGLImage {
  public var eglImage: UnsafeRawPointer
  public var width: Int
  public var height: Int

  private var _desktopEGLImage = FlutterDesktopEGLImage()

  public init(eglImage: UnsafeRawPointer, width: Int = 0, height: Int = 0) {
    self.eglImage = eglImage
    self.width = width
    self.height = height
  }

  fileprivate func getDesktopEGLImageTextureConfig(
    width: Int,
    height: Int,
    eglDisplay: UnsafeMutableRawPointer!,
    eglContext: UnsafeMutableRawPointer!
  ) -> UnsafePointer<FlutterDesktopEGLImage> {
    _desktopEGLImage.egl_image = eglImage
    _desktopEGLImage.width = self.width
    _desktopEGLImage.height = self.height
    _desktopEGLImage.release_context = _retainAnyObject(self)
    _desktopEGLImage.release_callback = _releaseAnyObject
    return withUnsafePointer(to: &_desktopEGLImage) { $0 }
  }
}

private func _getDesktopEGLImageTextureConfigThunk(
  width: Int,
  height: Int,
  egl_display: UnsafeMutableRawPointer?,
  egl_context: UnsafeMutableRawPointer?,
  user_data: UnsafeMutableRawPointer?
) -> UnsafePointer<FlutterDesktopEGLImage>? {
  Unmanaged<FlutterEGLImage>.fromOpaque(user_data!).takeUnretainedValue()
    .getDesktopEGLImageTextureConfig(
      width: width,
      height: height,
      eglDisplay: egl_display!,
      eglContext: egl_context!
    )
}

public enum FlutterTexture {
  case pixelBufferTexture(FlutterPixelBuffer)
  /* case gpuSurfaceTexture */ /* not supported */
  case eglImageTexture(FlutterEGLImage)

  fileprivate var _desktopTextureType: FlutterDesktopTextureType {
    switch self {
    case .pixelBufferTexture: return kFlutterDesktopPixelBufferTexture
    case .eglImageTexture: return kFlutterDesktopEGLImageTexture
    }
  }
}

public struct FlutterDesktopTextureRegistrar {
  private let registrar: flutter.FlutterELinuxTextureRegistrar

  private var _handle: FlutterDesktopTextureRegistrarRef {
    unsafeBitCast(registrar, to: FlutterDesktopTextureRegistrarRef.self)
  }

  public init(engine: FlutterEngine) {
    registrar = engine.textureRegistrar
  }

  init?(plugin: FlutterDesktopPluginRegistrar) {
    guard let registrar = plugin.registrar else { return nil }
    let textureRegistrarHandle = FlutterDesktopRegistrarGetTextureRegistrar(registrar)
    self.registrar = unsafeBitCast(
      textureRegistrarHandle,
      to: flutter.FlutterELinuxTextureRegistrar.self
    )
  }

  public func registerExternalTexture(_ texture: FlutterTexture) -> Int64 {
    var textureInfo = FlutterDesktopTextureInfo()
    textureInfo.type = texture._desktopTextureType
    switch texture {
    case let .pixelBufferTexture(config):
      _retainAnyObject(config) // to be released by unregisterExternalTexture
      textureInfo.pixel_buffer_config = FlutterDesktopPixelBufferTextureConfig(
        callback: _getDesktopPixelBufferTextureConfigThunk,
        user_data: Unmanaged.passUnretained(config).toOpaque()
      )
    case let .eglImageTexture(config):
      _retainAnyObject(config) // to be released by unregisterExternalTexture
      textureInfo.egl_image_config = FlutterDesktopEGLImageTextureConfig(
        callback: _getDesktopEGLImageTextureConfigThunk,
        user_data: Unmanaged.passUnretained(config).toOpaque()
      )
    }
    return registrar.RegisterTexture(&textureInfo)
  }

  public func unregisterExternalTexture(texture: FlutterTexture, id textureID: Int64) {
    let texturePtr: UnsafeMutableRawPointer

    switch texture {
    case let .pixelBufferTexture(config): texturePtr = Unmanaged.passUnretained(config).toOpaque()
    case let .eglImageTexture(config): texturePtr = Unmanaged.passUnretained(config).toOpaque()
    }

    // FIXME: use std::function
    FlutterDesktopTextureRegistrarUnregisterExternalTexture(
      _handle,
      textureID,
      _releaseAnyObject,
      texturePtr
    )
  }

  public func markExternalTextureFrameAvailable(textureID: Int64) {
    registrar.MarkTextureFrameAvailable(textureID)
  }
}

#endif
