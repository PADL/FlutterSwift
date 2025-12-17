/*
 * Copyright 2025 PADL Software Pty Ltd. All rights reserved.
 *
 * The information and source code contained herein is the exclusive
 * property of PADL Software Pty Ltd and may not be disclosed, examined
 * or reproduced in whole or in part without explicit written authorization
 * from the company.
 */

import CLibDRM
import Glibc
import SystemPackage

private extension String {
  init(cString: UnsafePointer<CChar>?, length: CInt) {
    guard let cString else { self.init(); return }
    let buffer = UnsafeRawBufferPointer(start: cString, count: Int(length))
    self.init(decoding: buffer, as: UTF8.self)
  }
}

public enum DRMModeConnection: UInt32 {
  case connected = 1
  case disconnected = 2
  case unknownConnection = 3
}

public enum DRMModeSubPixel: UInt32 {
  case unknown = 1
  case horizontalRGB = 2
  case horizontalBGR = 3
  case verticalRGB = 4
  case verticalBGR = 5
  case none = 6
}

public struct DRMVersion: ~Copyable {
  private var _ptr: drmVersionPtr!

  public init(_ fd: FileDescriptor) throws {
    _ptr = drmGetVersion(fd.rawValue)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var versionMajor: CInt {
    _ptr.pointee.version_major
  }

  public var versionMinor: CInt {
    _ptr.pointee.version_minor
  }

  public var versionPatchLevel: CInt {
    _ptr.pointee.version_patchlevel
  }

  public var name: String {
    String(cString: _ptr.pointee.name, length: _ptr.pointee.name_len)
  }

  deinit {
    drmFreeVersion(_ptr)
  }
}

public struct DRMModeResources: ~Copyable {
  private var _ptr: drmModeResPtr!

  public init(_ fd: FileDescriptor) throws {
    _ptr = drmModeGetResources(fd.rawValue)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var crtcs: [UInt32] {
    guard let crtcsPtr = _ptr.pointee.crtcs else { return [] }
    return Array(UnsafeBufferPointer(start: crtcsPtr, count: Int(_ptr.pointee.count_crtcs)))
  }

  public var connectors: [UInt32] {
    guard let connectorsPtr = _ptr.pointee.connectors else { return [] }
    return Array(UnsafeBufferPointer(
      start: connectorsPtr,
      count: Int(_ptr.pointee.count_connectors)
    ))
  }

  public var encoders: [UInt32] {
    guard let encodersPtr = _ptr.pointee.encoders else { return [] }
    return Array(UnsafeBufferPointer(start: encodersPtr, count: Int(_ptr.pointee.count_encoders)))
  }

  deinit {
    drmModeFreeResources(_ptr)
  }
}

public struct DRMModeModeInfo {
  private var _info: drmModeModeInfo

  public init(_ info: drmModeModeInfo) {
    _info = info
  }

  public var name: String {
    withUnsafeBytes(of: _info.name) { buffer in
      let cString = buffer.bindMemory(to: CChar.self)
      return String(cString: cString.baseAddress!)
    }
  }

  public var clock: UInt32 { _info.clock }
  public var hdisplay: UInt16 { _info.hdisplay }
  public var vdisplay: UInt16 { _info.vdisplay }
  public var vrefresh: UInt32 { _info.vrefresh }
  public var flags: UInt32 { _info.flags }
  public var type: UInt32 { _info.type }
}

public struct DRMModeCrtc: ~Copyable {
  private var _ptr: drmModeCrtcPtr!
  private var modeValid: Bool { _ptr.pointee.mode_valid != 0 }

  public init(_ fd: FileDescriptor, crtcId: UInt32) throws {
    _ptr = drmModeGetCrtc(fd.rawValue, crtcId)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var crtcId: UInt32 { _ptr.pointee.crtc_id }
  public var bufferId: UInt32 { _ptr.pointee.buffer_id }
  public var x: UInt32 { _ptr.pointee.x }
  public var y: UInt32 { _ptr.pointee.y }
  public var width: UInt32 { _ptr.pointee.width }
  public var height: UInt32 { _ptr.pointee.height }
  public var mode: DRMModeModeInfo? {
    guard modeValid else { return nil }
    return DRMModeModeInfo(_ptr.pointee.mode)
  }

  public var gammaSize: CInt { _ptr.pointee.gamma_size }

  deinit {
    drmModeFreeCrtc(_ptr)
  }
}

public struct DRMModeEncoder: ~Copyable {
  private var _ptr: drmModeEncoderPtr!

  public init(_ fd: FileDescriptor, encoderId: UInt32) throws {
    _ptr = drmModeGetEncoder(fd.rawValue, encoderId)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var encoderId: UInt32 { _ptr.pointee.encoder_id }
  public var encoderType: UInt32 { _ptr.pointee.encoder_type }
  public var crtcId: UInt32 { _ptr.pointee.crtc_id }
  public var possibleCrtcs: UInt32 { _ptr.pointee.possible_crtcs }
  public var possibleClones: UInt32 { _ptr.pointee.possible_clones }

  deinit {
    drmModeFreeEncoder(_ptr)
  }
}

public struct DRMModeConnector: ~Copyable {
  private var _ptr: drmModeConnectorPtr!

  public init(_ fd: FileDescriptor, connectorId: UInt32) throws {
    _ptr = drmModeGetConnector(fd.rawValue, connectorId)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var connectorId: UInt32 { _ptr.pointee.connector_id }
  public var encoderId: UInt32 { _ptr.pointee.encoder_id }
  public var connectorType: UInt32 { _ptr.pointee.connector_type }
  public var connectorTypeId: UInt32 { _ptr.pointee.connector_type_id }
  public var connection: DRMModeConnection? {
    DRMModeConnection(rawValue: _ptr.pointee.connection.rawValue)
  }

  public var mmWidth: UInt32 { _ptr.pointee.mmWidth }
  public var mmHeight: UInt32 { _ptr.pointee.mmHeight }
  public var subpixel: DRMModeSubPixel? {
    DRMModeSubPixel(rawValue: _ptr.pointee.subpixel.rawValue)
  }

  public var modes: [DRMModeModeInfo] {
    guard let modesPtr = _ptr.pointee.modes else { return [] }
    return (0..<Int(_ptr.pointee.count_modes)).map { i in
      DRMModeModeInfo(modesPtr[i])
    }
  }

  public var properties: [DRMModeObjectProperty] {
    guard let propsPtr = _ptr.pointee.props,
          let propValuesPtr = _ptr.pointee.prop_values else { return [] }
    return (0..<Int(_ptr.pointee.count_props)).map { i in
      DRMModeObjectProperty(property: propsPtr[i], propertyValue: propValuesPtr[i])
    }
  }

  public var encoders: [UInt32] {
    guard let encodersPtr = _ptr.pointee.encoders else { return [] }
    return Array(UnsafeBufferPointer(start: encodersPtr, count: Int(_ptr.pointee.count_encoders)))
  }

  deinit {
    drmModeFreeConnector(_ptr)
  }
}

public struct DRMModeProperty: ~Copyable {
  private var _ptr: drmModePropertyPtr!

  public init(_ fd: FileDescriptor, propertyId: UInt32) throws {
    _ptr = drmModeGetProperty(fd.rawValue, propertyId)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var propId: UInt32 { _ptr.pointee.prop_id }
  public var flags: UInt32 { _ptr.pointee.flags }
  public var propertyType: UInt32 { drmModeGetPropertyType(_ptr) }

  public var name: String {
    withUnsafeBytes(of: _ptr.pointee.name) { buffer in
      let cString = buffer.bindMemory(to: CChar.self)
      return String(cString: cString.baseAddress!)
    }
  }

  public var values: [UInt64] {
    guard let valuesPtr = _ptr.pointee.values else { return [] }
    return Array(UnsafeBufferPointer(start: valuesPtr, count: Int(_ptr.pointee.count_values)))
  }

  public var enums: [(UInt64, String)] {
    guard let enumsPtr = _ptr.pointee.enums else { return [] }
    return (0..<Int(_ptr.pointee.count_enums)).map { i in
      let enumVal = enumsPtr[i]
      let name = withUnsafeBytes(of: enumVal.name) { buffer in
        let cString = buffer.bindMemory(to: CChar.self)
        return String(cString: cString.baseAddress!)
      }
      return (enumVal.value, name)
    }
  }

  public var blobIds: [UInt32] {
    guard let blobIdsPtr = _ptr.pointee.blob_ids else { return [] }
    return Array(UnsafeBufferPointer(start: blobIdsPtr, count: Int(_ptr.pointee.count_blobs)))
  }

  deinit {
    drmModeFreeProperty(_ptr)
  }
}

public struct DRMModePropertyBlob: ~Copyable {
  private var _ptr: drmModePropertyBlobPtr!

  public init(_ fd: FileDescriptor, blobId: UInt32) throws {
    _ptr = drmModeGetPropertyBlob(fd.rawValue, blobId)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var id: UInt32 { _ptr.pointee.id }

  public var data: [UInt8] {
    guard let dataPtr = _ptr.pointee.data else { return [] }
    let buffer = UnsafeRawBufferPointer(start: dataPtr, count: Int(_ptr.pointee.length))
    return Array(buffer)
  }

  deinit {
    drmModeFreePropertyBlob(_ptr)
  }
}

public struct DRMModeFB2: ~Copyable {
  private var _ptr: drmModeFB2Ptr!

  public init(_ fd: FileDescriptor, bufferId: UInt32) throws {
    _ptr = drmModeGetFB2(fd.rawValue, bufferId)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var fbId: UInt32 { _ptr.pointee.fb_id }
  public var width: UInt32 { _ptr.pointee.width }
  public var height: UInt32 { _ptr.pointee.height }
  public var pixelFormat: UInt32 { _ptr.pointee.pixel_format }
  public var modifier: UInt64 { _ptr.pointee.modifier }
  public var flags: UInt32 { _ptr.pointee.flags }

  public var handles: [UInt32] {
    withUnsafeBytes(of: _ptr.pointee.handles) { buffer in
      Array(buffer.bindMemory(to: UInt32.self))
    }
  }

  public var pitches: [UInt32] {
    withUnsafeBytes(of: _ptr.pointee.pitches) { buffer in
      Array(buffer.bindMemory(to: UInt32.self))
    }
  }

  public var offsets: [UInt32] {
    withUnsafeBytes(of: _ptr.pointee.offsets) { buffer in
      Array(buffer.bindMemory(to: UInt32.self))
    }
  }

  deinit {
    drmModeFreeFB2(_ptr)
  }
}

public struct DRMModeObjectProperty {
  public var property: UInt32
  public var propertyValue: UInt64

  public init(property: UInt32, propertyValue: UInt64) {
    self.property = property
    self.propertyValue = propertyValue
  }
}

public struct DRMModeObjectProperties: ~Copyable {
  private var _ptr: drmModeObjectPropertiesPtr!

  public init(_ fd: FileDescriptor, objectId: UInt32, objectType: UInt32) throws {
    _ptr = drmModeObjectGetProperties(fd.rawValue, objectId, objectType)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var properties: [DRMModeObjectProperty] {
    guard let propsPtr = _ptr.pointee.props,
          let propValuesPtr = _ptr.pointee.prop_values else { return [] }
    return (0..<Int(_ptr.pointee.count_props)).map { i in
      DRMModeObjectProperty(property: propsPtr[i], propertyValue: propValuesPtr[i])
    }
  }

  deinit {
    drmModeFreeObjectProperties(_ptr)
  }
}

public struct DRMModePlane: ~Copyable {
  private var _ptr: drmModePlanePtr!

  public init(_ fd: FileDescriptor, planeId: UInt32) throws {
    _ptr = drmModeGetPlane(fd.rawValue, planeId)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var planeId: UInt32 { _ptr.pointee.plane_id }
  public var crtcId: UInt32 { _ptr.pointee.crtc_id }
  public var fbId: UInt32 { _ptr.pointee.fb_id }
  public var crtcX: UInt32 { _ptr.pointee.crtc_x }
  public var crtcY: UInt32 { _ptr.pointee.crtc_y }
  public var x: UInt32 { _ptr.pointee.x }
  public var y: UInt32 { _ptr.pointee.y }
  public var possibleCrtcs: UInt32 { _ptr.pointee.possible_crtcs }
  public var gammaSize: UInt32 { _ptr.pointee.gamma_size }

  public var formats: [UInt32] {
    guard let formatsPtr = _ptr.pointee.formats else { return [] }
    return Array(UnsafeBufferPointer(start: formatsPtr, count: Int(_ptr.pointee.count_formats)))
  }

  deinit {
    drmModeFreePlane(_ptr)
  }
}

public struct DRMModePlaneRes: ~Copyable {
  private var _ptr: drmModePlaneResPtr!

  public init(_ fd: FileDescriptor) throws {
    _ptr = drmModeGetPlaneResources(fd.rawValue)
    if _ptr == nil { throw Errno(rawValue: errno) }
  }

  public var planes: [UInt32] {
    guard let planesPtr = _ptr.pointee.planes else { return [] }
    return Array(UnsafeBufferPointer(start: planesPtr, count: Int(_ptr.pointee.count_planes)))
  }

  deinit {
    drmModeFreePlaneResources(_ptr)
  }
}
