// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

#if os(macOS)
  import TDK4AppKit

  public typealias CtlCandidateTDKOLD = TDK4AppKit.CtlCandidateTDK4AppKit
  public typealias CtlCandidateTDK = GSI4AppKit.CtlCandidateGSI4AppKit
#endif
