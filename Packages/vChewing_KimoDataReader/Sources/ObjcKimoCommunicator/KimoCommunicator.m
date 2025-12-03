// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// 免責聲明：
// 與奇摩輸入法有關的原始碼是由 Yahoo 奇摩以 `SPDX Identifier: BSD-3-Clause` 釋出的，
// 但敝模組只是藉由其 Protocol API 與該當程式進行跨執行緒通訊，所以屬於合理使用範圍。

#import "KimoCommunicator.h"

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <os/log.h>

void ConsoleLog(NSString *format, ...) {
  va_list args;
  va_start(args, format);

  if (@available(macOS 26, *)) {
    // 使用 os_log，避免 <private> 問題
    os_log_t log = os_log_create("vChewing", "KimoCommunicator");
    va_list copy;
    va_copy(copy, args);
    NSString *fullMessage = [[NSString alloc] initWithFormat:format
                                                   arguments:copy];
    va_end(copy);
    // 使用 %{public}@ 來公開顯示字串，避免模糊；根據需要調整級別如
    // OS_LOG_TYPE_DEBUG
    os_log_with_type(log, OS_LOG_TYPE_DEFAULT, "%{public}@", fullMessage);
  } else {
    // 回退到 NSLog，兼容舊系統
    NSString *fullMessage = [[NSString alloc] initWithFormat:format
                                                   arguments:args];
    NSLog(@"%@", fullMessage);
  }
  va_end(args);
}

#define kYahooKimoDataObjectConnectionName @"YahooKeyKeyService"

@implementation ObjcKimoCommunicator {
  id _xpcConnection;
}

/// 解構。
- (void)dealloc {
  [self disconnect];
}

/// 斷開連線。
- (void)disconnect {
  _xpcConnection = nil;
}

/// 嘗試連線。
- (bool)establishConnection {
  // 奇摩輸入法2012最終版在建置的時候還沒用到 NSXPCConnection，實質上並不支援
  // NSXPCConnection。 因此，這裡使用 NSXPCConnection 的話反而會壞事。
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
  _xpcConnection = [NSConnection rootProxyForConnectionWithRegisteredName:
                                     kYahooKimoDataObjectConnectionName
                                                                     host:nil];
#pragma GCC diagnostic pop
  BOOL result = false;
  if (_xpcConnection) {
    result = true;
  }
  if (result) {
    [_xpcConnection setProtocolForProxy:@protocol(KimoUserDataReaderService)];
    ConsoleLog(
        @"vChewingDebug: Connection successful. Available data amount: %d.\n",
        [_xpcConnection userPhraseDBNumberOfRow]);
  }
  return result;
}

/// 偵測連線是否有效。
- (bool)hasValidConnection {
  BOOL result = false;
  if (_xpcConnection) result = true;
  return result;
}

- (BOOL)userPhraseDBCanProvideService {
  return [self hasValidConnection]
             ? [_xpcConnection userPhraseDBCanProvideService]
             : NO;
}

- (int)userPhraseDBTotalAmountOfRows {
  return [self hasValidConnection] ? [_xpcConnection userPhraseDBNumberOfRow]
                                   : 0;
}

- (NSDictionary<NSString *, NSString *> *)userPhraseDBDictionaryAtRow:(int)row {
  return [self hasValidConnection]
             ? [_xpcConnection userPhraseDBDictionaryAtRow:row]
             : [NSDictionary alloc];
}

- (bool)exportUserPhraseDBToFile:(NSString *)path {
  return [self hasValidConnection]
             ? [_xpcConnection exportUserPhraseDBToFile:path]
             : NO;
}

@end
