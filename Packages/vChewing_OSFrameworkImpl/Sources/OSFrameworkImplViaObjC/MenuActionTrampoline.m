// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

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
