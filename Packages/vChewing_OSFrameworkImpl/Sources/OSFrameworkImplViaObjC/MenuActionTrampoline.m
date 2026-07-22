// (c) 2026 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#import "MenuActionTrampoline.h"

@implementation NSMenuActionTrampoline {
  void (^_action)(void);
}

- (instancetype)initWithBlock:(void (^)(void))block {
  if (self = [super init]) {
    _action = [block copy];
  }
  return self;
}

- (void)fire:(id)sender {
  if (_action) _action();
}

- (nullable void (^)(void))actionBlock {
  return [[_action retain] autorelease];
}

- (void)dealloc {
  if (_action) {
    [_action release];
    _action = nil;
  }
  [super dealloc];
}

@end
