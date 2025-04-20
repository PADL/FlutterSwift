//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if os(Linux) && canImport(Glibc)

@_implementationOnly
import CxxFlutterSwift
import CxxStdlib

/// Compute the prefix sum of `seq`.
func scan<
  S: Sequence, U
>(_ seq: S, _ initial: U, _ combine: (U, S.Element) -> U) -> [U] {
  var result: [U] = []
  result.reserveCapacity(seq.underestimatedCount)
  var runningResult = initial
  for element in seq {
    runningResult = combine(runningResult, element)
    result.append(runningResult)
  }
  return result
}

func withArrayOfCStrings<R>(
  _ args: [String],
  _ body: (inout [UnsafePointer<CChar>?]) -> R
) -> R {
  let argsCounts = Array(args.map { $0.utf8.count + 1 })
  let argsOffsets = [0] + scan(argsCounts, 0, +)
  let argsBufferSize = argsOffsets.last!

  var argsBuffer: [UInt8] = []
  argsBuffer.reserveCapacity(argsBufferSize)
  for arg in args {
    argsBuffer.append(contentsOf: arg.utf8)
    argsBuffer.append(0)
  }

  return argsBuffer.withUnsafeMutableBufferPointer {
    argsBuffer in
    let ptr = UnsafeRawPointer(argsBuffer.baseAddress!).bindMemory(
      to: CChar.self, capacity: argsBuffer.count
    )
    var cStrings: [UnsafePointer<CChar>?] = argsOffsets.map { ptr + $0 }
    cStrings[cStrings.count - 1] = nil
    return body(&cStrings)
  }
}

// https://stackoverflow.com/questions/49451164/convert-swift-string-to-wchar-t
extension String {
  /// Calls the given closure with a pointer to the contents of the string,
  /// represented as a null-terminated wchar_t array.
  func withWideChars<Result>(_ body: (UnsafePointer<CWideChar>) -> Result) -> Result {
    let u32: [CWideChar] = unicodeScalars.map { CWideChar($0.value)! } + [CWideChar(0)]
    return u32.withUnsafeBufferPointer { body($0.baseAddress!) }
  }
}

extension Array where Element == String {
  var cxxVector: CxxVectorOfString {
    var tmp = CxxVectorOfString()

    for element in self {
      tmp.push_back(std.string(element))
    }

    return tmp
  }
}
#endif
