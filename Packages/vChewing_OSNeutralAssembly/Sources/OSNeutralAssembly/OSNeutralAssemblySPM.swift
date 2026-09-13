// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

@_exported import BPMFVS
@_exported import BrailleSputnik
@_exported import Homa
@_exported import LexiconAssembly
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
