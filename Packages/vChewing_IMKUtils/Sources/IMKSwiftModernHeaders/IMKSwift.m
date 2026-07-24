// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

/// @file IMKSwift.m
/// @brief Implementation file for `IMKInputSessionController`.
///
/// This file provides the `@implementation` block for `IMKInputSessionController`,
/// which is declared in `IMKSwift.h` as a subclass of `IMKInputController`.
///
/// All IMK dispatch is handled via **class-level static blocks** — set once from
/// Swift at startup via `+IMKSwift_configureWithActivatingServer:...`, shared by
/// all controller instances.  Each block receives raw `uintptr_t` memory addresses
/// instead of object references — no retain/release is performed on the client
/// or the controller itself.  This eliminates per-instance block ivars, MRC
/// life‑cycle management, delayed‑dealloc block release, and `-activateServer:`
/// re‑injection complexity.

#import <Foundation/Foundation.h>
#import <InputMethodKit/InputMethodKit.h>
#import <objc/runtime.h>
#import "include/IMKSwift.h"

NS_ASSUME_NONNULL_BEGIN

// Forward-declare private IMK class methods used by the dealloc path.
// +respondsToSelector: guards call sites at runtime, but the compiler still
// needs to know the selector signatures to avoid -Wundeclared-selector warnings.
@interface NSObject (IPMDServerClientWrapperTermination)
+ (void)terminateForClientXPCConn:(id)client;
+ (void)terminateForClientDOProxy:(id)client;
+ (void)terminateForClient:(id)client;
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// MARK: - Class-level Static Blocks (shared by all controller instances)

static void (^_IMKSwift_onActivatingServer)(uintptr_t, uintptr_t);
static void (^_IMKSwift_onDeactivatingServer)(uintptr_t, uintptr_t);
static void (^_IMKSwift_onDealloc)(uintptr_t);
static void (^_IMKSwift_onShowingPreferences)(uintptr_t, uintptr_t);
static void (^_IMKSwift_onHidingPallettes)(uintptr_t);
static void (^_IMKSwift_onInputControllerWillClose)(uintptr_t);
static NSRange (^_IMKSwift_onProvidingSelectionRange)(uintptr_t);
static NSMenu * _Nullable (^_IMKSwift_onProvidingIMEMenu)(uintptr_t);
static id _Nullable (^_IMKSwift_onProvidingComposedString)(uintptr_t, uintptr_t);
static void (^_IMKSwift_onAutoCommittingComposition)(uintptr_t, uintptr_t);
static NSUInteger (^_IMKSwift_onProvidingRecognizedEvents)(uintptr_t, uintptr_t);
static BOOL (^_IMKSwift_onHandlingGivenNullableEvent)(uintptr_t, uintptr_t, uintptr_t);
static void (^_IMKSwift_onSettingObjCValue)(uintptr_t, intptr_t, uintptr_t, uintptr_t);

@implementation IMKInputSessionController

// MARK: - Class Method: One-time Block Configuration (called from Swift at startup)

+ (void)IMKSwift_configureWithActivatingServer:(nullable void (^)(uintptr_t, uintptr_t))blk {
    if (_IMKSwift_onActivatingServer != blk) {
        [_IMKSwift_onActivatingServer release];
        _IMKSwift_onActivatingServer = [blk copy];
    }
}
+ (void)IMKSwift_configureWithDeactivatingServer:(nullable void (^)(uintptr_t, uintptr_t))blk {
    if (_IMKSwift_onDeactivatingServer != blk) {
        [_IMKSwift_onDeactivatingServer release];
        _IMKSwift_onDeactivatingServer = [blk copy];
    }
}
+ (void)IMKSwift_configureWithDealloc:(nullable void (^)(uintptr_t))blk {
    if (_IMKSwift_onDealloc != blk) {
        [_IMKSwift_onDealloc release];
        _IMKSwift_onDealloc = [blk copy];
    }
}
+ (void)IMKSwift_configureWithShowingPreferences:(nullable void (^)(uintptr_t, uintptr_t))blk {
    if (_IMKSwift_onShowingPreferences != blk) {
        [_IMKSwift_onShowingPreferences release];
        _IMKSwift_onShowingPreferences = [blk copy];
    }
}
+ (void)IMKSwift_configureWithHidingPallettes:(nullable void (^)(uintptr_t))blk {
    if (_IMKSwift_onHidingPallettes != blk) {
        [_IMKSwift_onHidingPallettes release];
        _IMKSwift_onHidingPallettes = [blk copy];
    }
}
+ (void)IMKSwift_configureWithInputControllerWillClose:(nullable void (^)(uintptr_t))blk {
    if (_IMKSwift_onInputControllerWillClose != blk) {
        [_IMKSwift_onInputControllerWillClose release];
        _IMKSwift_onInputControllerWillClose = [blk copy];
    }
}
+ (void)IMKSwift_configureWithProvidingSelectionRange:(nullable NSRange (^)(uintptr_t))blk {
    if (_IMKSwift_onProvidingSelectionRange != blk) {
        [_IMKSwift_onProvidingSelectionRange release];
        _IMKSwift_onProvidingSelectionRange = [blk copy];
    }
}
+ (void)IMKSwift_configureWithProvidingIMEMenu:(nullable NSMenu * _Nullable (^)(uintptr_t))blk {
    if (_IMKSwift_onProvidingIMEMenu != blk) {
        [_IMKSwift_onProvidingIMEMenu release];
        _IMKSwift_onProvidingIMEMenu = [blk copy];
    }
}
+ (void)IMKSwift_configureWithProvidingComposedString:(nullable id _Nullable (^)(uintptr_t, uintptr_t))blk {
    if (_IMKSwift_onProvidingComposedString != blk) {
        [_IMKSwift_onProvidingComposedString release];
        _IMKSwift_onProvidingComposedString = [blk copy];
    }
}
+ (void)IMKSwift_configureWithAutoCommittingComposition:(nullable void (^)(uintptr_t, uintptr_t))blk {
    if (_IMKSwift_onAutoCommittingComposition != blk) {
        [_IMKSwift_onAutoCommittingComposition release];
        _IMKSwift_onAutoCommittingComposition = [blk copy];
    }
}
+ (void)IMKSwift_configureWithProvidingRecognizedEvents:(nullable NSUInteger (^)(uintptr_t, uintptr_t))blk {
    if (_IMKSwift_onProvidingRecognizedEvents != blk) {
        [_IMKSwift_onProvidingRecognizedEvents release];
        _IMKSwift_onProvidingRecognizedEvents = [blk copy];
    }
}
+ (void)IMKSwift_configureWithHandlingGivenNullableEvent:(nullable BOOL (^)(uintptr_t, uintptr_t, uintptr_t))blk {
    if (_IMKSwift_onHandlingGivenNullableEvent != blk) {
        [_IMKSwift_onHandlingGivenNullableEvent release];
        _IMKSwift_onHandlingGivenNullableEvent = [blk copy];
    }
}
+ (void)IMKSwift_configureWithSettingObjCValue:(nullable void (^)(uintptr_t, intptr_t, uintptr_t, uintptr_t))blk {
    if (_IMKSwift_onSettingObjCValue != blk) {
        [_IMKSwift_onSettingObjCValue release];
        _IMKSwift_onSettingObjCValue = [blk copy];
    }
}

// MARK: - Lifecycle

- (void)dealloc {
    if (_IMKSwift_onDealloc) _IMKSwift_onDealloc((uintptr_t)self);
    [self IMKSwift_cancelDelayedDealloc];
    [super dealloc];
}

// MARK: - Stale Controller Pruning (Class Method)

/// Monotonically increasing generation counter used to identify the oldest
/// controller in `_controllers`.  Each `IMKInputSessionController` receives
/// a generation stamp via `objc_setAssociatedObject` during `-initWithServer:…`.
static uint64_t _IMKSwift_controllerGeneration = 0;

/// Key for the associated-object generation stamp.
static char kIMKSwiftGenerationKey;

/// Removes the oldest stale controller from `IMKServer._private._controllers`
/// when the dictionary has grown beyond a healthy threshold.
///
/// CpLk toggling causes IMKServer to create a new DO/XPC proxy on every
/// activation.  Because `_controllers` is keyed by proxy memory address,
/// each toggle creates a new orphan entry — the old proxy is gone and its
/// `-sessionFinished:` will never fire.  This method evicts the oldest
/// non-current controller, keeping the dictionary bounded.
///
/// @param server         The `IMKServer` whose `_controllers` dictionary to prune.
/// @param selfController The controller currently being initialised (excluded from eviction).
+ (void)IMKSwift_pruneStaleControllersOnServer:(IMKServer *)server
                                  excludingSelf:(id)selfController {
    id serverPvt = [server valueForKey:@"_private"];
    NSMutableDictionary *ctls = [serverPvt valueForKey:@"_controllers"];
    if (!ctls || [ctls count] <= 2) return;

    id currentCtl = [serverPvt valueForKey:@"_currentController"];

    // Find the oldest controller (lowest generation) that is safe to evict.
    id oldest = nil;
    uint64_t oldestGen = UINT64_MAX;
    for (id ctl in [ctls allValues]) {
        if (ctl == currentCtl || ctl == selfController) continue;
        NSNumber *genNum = objc_getAssociatedObject(ctl, &kIMKSwiftGenerationKey);
        uint64_t gen = genNum ? [genNum unsignedLongLongValue] : 0;
        if (gen < oldestGen) {
            oldestGen = gen;
            oldest = ctl;
        }
    }
    if (!oldest) return;

    // Find the dictionary key for the oldest controller and remove it.
    for (id key in [ctls allKeys]) {
        if ([ctls objectForKey:key] == oldest) {
            [ctls removeObjectForKey:key];
            break;
        }
    }
}

// MARK: - Parity / Generation

+ (uint64_t)IMKSwift_currentGeneration {
    return _IMKSwift_controllerGeneration;
}

// MARK: - Initializer

- (instancetype)initWithServer:(IMKServer *)server delegate:(nullable id)delegate client:(id)inputClient {
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self) {
        NSNumber *gen = [NSNumber numberWithUnsignedLongLong:++_IMKSwift_controllerGeneration];
        objc_setAssociatedObject(self, &kIMKSwiftGenerationKey, gen, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [IMKInputSessionController IMKSwift_pruneStaleControllersOnServer:server excludingSelf:self];

        SEL hookSel = @selector(onSuperConstructionSucceeded:delegate:client:);
        if ([self respondsToSelector:hookSel]) {
            NSMethodSignature *sig = [self methodSignatureForSelector:hookSel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setSelector:hookSel];
            [inv setTarget:self];
            [inv setArgument:&server atIndex:2];
            [inv setArgument:&delegate atIndex:3];
            [inv setArgument:&inputClient atIndex:4];
            [inv invoke];
        }
    }
    return self;
}

// MARK: - IMKInputController Overrides (dispatch via class-level static blocks)

- (void)activateServer:(id)sender {
    [self IMKSwift_cancelDelayedDealloc];
    if (_IMKSwift_onActivatingServer) _IMKSwift_onActivatingServer((uintptr_t)sender, (uintptr_t)self);
}

- (void)deactivateServer:(id)sender {
    if (_IMKSwift_onDeactivatingServer) _IMKSwift_onDeactivatingServer((uintptr_t)sender, (uintptr_t)self);
    [self IMKSwift_scheduleDelayedDeallocAfterDelay:3.0];
}

- (void)showPreferences:(nullable id)sender {
    if (_IMKSwift_onShowingPreferences) _IMKSwift_onShowingPreferences((uintptr_t)sender, (uintptr_t)self);
}

- (void)hidePalettes {
    if (_IMKSwift_onHidingPallettes) _IMKSwift_onHidingPallettes((uintptr_t)self);
}

- (void)inputControllerWillClose {
    if (_IMKSwift_onInputControllerWillClose) _IMKSwift_onInputControllerWillClose((uintptr_t)self);
}

- (NSRange)selectionRange {
    if (_IMKSwift_onProvidingSelectionRange) return _IMKSwift_onProvidingSelectionRange((uintptr_t)self);
    return NSMakeRange(NSNotFound, 0);
}

- (nullable NSMenu *)menu {
    if (_IMKSwift_onProvidingIMEMenu) return _IMKSwift_onProvidingIMEMenu((uintptr_t)self);
    return [[NSMenu new] autorelease];
}

- (nullable id)composedString:(id)sender {
    if (_IMKSwift_onProvidingComposedString) return _IMKSwift_onProvidingComposedString((uintptr_t)sender, (uintptr_t)self);
    return nil;
}

- (void)commitComposition:(id)sender {
    if (_IMKSwift_onAutoCommittingComposition) _IMKSwift_onAutoCommittingComposition((uintptr_t)sender, (uintptr_t)self);
}

- (NSUInteger)recognizedEvents:(id)sender {
    if (_IMKSwift_onProvidingRecognizedEvents) return _IMKSwift_onProvidingRecognizedEvents((uintptr_t)sender, (uintptr_t)self);
    return 0;
}

- (BOOL)handleEvent:(nullable NSEvent *)event client:(id)sender {
    if (_IMKSwift_onHandlingGivenNullableEvent) return _IMKSwift_onHandlingGivenNullableEvent((uintptr_t)event, (uintptr_t)sender, (uintptr_t)self);
    return NO;
}

- (void)setValue:(nullable id)value forTag:(NSInteger)tag client:(id)sender {
    if (_IMKSwift_onSettingObjCValue) _IMKSwift_onSettingObjCValue((uintptr_t)value, (intptr_t)tag, (uintptr_t)sender, (uintptr_t)self);
}

// MARK: - Private: Deferred Dealloc

/// Schedules a delayed dealloc of this controller after `delay` seconds.
/// The `performSelector:withObject:afterDelay:` API retains `self` for the
/// duration of the delay.  When the timer fires, the timer releases its retain.
/// If no other objects hold a reference, `-dealloc` is triggered by the system.
- (void)IMKSwift_scheduleDelayedDeallocAfterDelay:(NSTimeInterval)delay {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(IMKSwift_delayedDealloc)
                                               object:nil];
    [self performSelector:@selector(IMKSwift_delayedDealloc)
               withObject:nil
               afterDelay:delay];
}

/// Cancels any pending delayed dealloc.
- (void)IMKSwift_cancelDelayedDealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(IMKSwift_delayedDealloc)
                                               object:nil];
}

/// Triggers the dealloc callback, then terminates the client wrapper to release
/// the underlying XPC connection.  Block ivars are class-level static — no
/// per-instance release needed.
- (void)IMKSwift_delayedDealloc {
    if (_IMKSwift_onDealloc) _IMKSwift_onDealloc((uintptr_t)self);
    // Terminate the client wrapper so that IMK's global wrapper cache
    // and the underlying XPC connection are released promptly.  The controller
    // shell may persist in _controllers until the next prune cycle, but the
    // heavy XPC resources (~440 bytes per connection) are freed now.
    id clientProxy = [self client];
    if (clientProxy) {
        // macOS 15 Sequoia split IPMDServerClientWrapper into Modern / Legacy subclasses.
        // Try both variants, then fall back to the undecorated name for ≤10.15.
        Class wrapperClass = nil;
        for (NSString *name in @[
            @"_IPMDServerClientWrapperModern",
            @"_IPMDServerClientWrapperLegacy",
            @"IPMDServerClientWrapper"
        ]) {
            wrapperClass = NSClassFromString(name);
            if (wrapperClass) break;
        }
        if (wrapperClass) {
            if ([wrapperClass respondsToSelector:@selector(terminateForClientXPCConn:)]) {
                [wrapperClass terminateForClientXPCConn:clientProxy];
            } else if ([wrapperClass respondsToSelector:@selector(terminateForClientDOProxy:)]) {
                [wrapperClass terminateForClientDOProxy:clientProxy];
            } else if ([wrapperClass respondsToSelector:@selector(terminateForClient:)]) {
                [wrapperClass terminateForClient:clientProxy];
            }
        }
    }
}

@end

#pragma clang diagnostic pop

NS_ASSUME_NONNULL_END
