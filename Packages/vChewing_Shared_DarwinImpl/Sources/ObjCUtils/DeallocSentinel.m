// (c) 2025 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#import "DeallocSentinel.h"

@implementation DeallocSentinel {
  void (^_onDealloc)(void);
}

- (instancetype)initWithBlock:(void (^)(void))block {
  if (self = [super init]) {
    _onDealloc = [block copy];
  }
  return self;
}

- (void)dealloc {
  if (_onDealloc) {
    _onDealloc();
    [_onDealloc release];
    _onDealloc = nil;
  }
  [super dealloc];
}

@end
