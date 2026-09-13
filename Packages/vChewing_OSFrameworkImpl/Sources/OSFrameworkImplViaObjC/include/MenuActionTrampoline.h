// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A trampoline that bridges an `NSMenuItem` action to an ObjC block.
///
/// Intended for use as the `target` of an `NSMenuItem`: create one with a
/// closure, set `fire:` as the item's action, and attach the trampoline as
/// an associated object on the menu item (so it lives exactly as long as the
/// item does).
@interface NSMenuActionTrampoline : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithBlock:(void (^)(void))block NS_DESIGNATED_INITIALIZER;

- (void)fire:(id)sender;

/// The stored block, or nil if already consumed.
@property (readonly, nullable) void (^actionBlock)(void);

@end

NS_ASSUME_NONNULL_END
