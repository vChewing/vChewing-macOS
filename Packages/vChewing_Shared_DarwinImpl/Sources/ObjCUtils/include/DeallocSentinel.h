// (c) 2025 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A lightweight sentinel that executes a block when deallocated.
///
/// Attach to any NSObject via `objc_setAssociatedObject`. When the host
/// object is deallocated, the Objective-C runtime automatically releases
/// all associated objects, triggering this sentinel's `-dealloc` and
/// thus the callback block.
///
/// This mechanism works independently of ARC/MRC — the runtime's
/// associated object cleanup does not depend on compiler flags.
@interface DeallocSentinel : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithBlock:(void (^)(void))block NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
