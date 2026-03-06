// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

/// @file IMKSwift.m
/// @brief Minimal implementation file for `IMKInputSessionController`.
///
/// This file provides the `@implementation` block for `IMKInputSessionController`,
/// which is declared in `IMKSwift.h` as a subclass of `IMKInputController`.
///
/// Because `IMKInputSessionController` re-declares inherited methods from
/// `IMKInputController` (with refined nullability and `@MainActor` annotations),
/// the compiler would normally emit `-Wincomplete-implementation` warnings for
/// each method that lacks an explicit body.  The `#pragma clang diagnostic`
/// block suppresses these warnings — the actual implementations are inherited
/// from `IMKInputController` at runtime via the Objective-C message dispatch.
///
/// **No method bodies are needed here.** Downstream Swift subclasses override
/// the methods declared in `IMKSwift.h` and the Objective-C runtime resolves
/// them through the normal inheritance chain.

#import <Foundation/Foundation.h>
#import <InputMethodKit/InputMethodKit.h>
#import "include/IMKSwift.h"

NS_ASSUME_NONNULL_BEGIN

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

/// Empty `@implementation` block for `IMKInputSessionController`.
///
/// All method implementations are inherited from `IMKInputController`.
/// This block exists solely to satisfy the Objective-C linker's requirement
/// that every `@interface … : SuperClass` declared class has a corresponding
/// `@implementation`.
@implementation IMKInputSessionController
@end

#pragma clang diagnostic pop

NS_ASSUME_NONNULL_END
