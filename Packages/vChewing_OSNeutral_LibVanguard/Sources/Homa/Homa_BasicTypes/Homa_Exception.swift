// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

extension Homa {
  public enum Exception: Error {
    case givenKeyIsEmpty
    case givenKeyHasNoResults
    case deleteKeyAgainstBorder
    case cursorAlreadyAtBorder
    case cursorRegionMapMatchingFailure
    case nothingOverriddenAtNode
    case noNodesAssigned
    case assemblerIsEmpty
    case noCandidatesAvailableToRevolve
    case onlyOneCandidateAvailableToRevolve
    case cursorOutOfReasonableNodeRegions
    case nodeHasNoCurrentGram
    case upperboundSmallerThanLowerbound
  }
}
