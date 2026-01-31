// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

@_exported import BrailleSputnik
@_exported import LangModelAssembly
@_exported import Megrez
@_exported import Shared
@_exported import SwiftExtension
@_exported import Tekkon

#if canImport(Musl)
  @_exported import Musl
#elseif canImport(Glibc)
  @_exported import Glibc
#elseif canImport(Darwin)
  @_exported import Darwin
#elseif canImport(ucrt)
  @_exported import ucrt
#endif
