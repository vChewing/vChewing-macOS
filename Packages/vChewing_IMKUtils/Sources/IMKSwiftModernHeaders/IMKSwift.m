// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

/// @file IMKSwift.m
/// @brief Implementation file for `IMKInputSessionController`.
///
/// This file provides the `@implementation` block for `IMKInputSessionController`,
/// which is declared in `IMKSwift.h` as a subclass of `IMKInputController`.
///
/// **All** `IMKInputController` overrides are implemented here; each invokes the
/// corresponding block property set by the Swift subclass.  The blocks receive
/// raw memory addresses (`uintptr_t`) instead of object references — no
/// retain/release is performed on the client or the controller itself.
///
/// The `-Wincomplete-implementation` pragma is still needed for the remaining
/// methods that are inherited from `IMKInputController` at runtime without
/// explicit bodies (e.g. `candidates:`, `doCommandBy:`).

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

@implementation IMKInputSessionController {
    void (^_onActivatingServer)(uintptr_t, uintptr_t);
    void (^_onDeactivatingServer)(uintptr_t, uintptr_t);
    void (^_onDealloc)(uintptr_t);
    void (^_onShowingPreferences)(uintptr_t, uintptr_t);
    void (^_onHidingPallettes)(uintptr_t);
    void (^_onInputControllerWillClose)(uintptr_t);
    NSRange (^_onProvidingSelectionRange)(uintptr_t);
    NSMenu * _Nullable (^_onProvidingIMEMenu)(uintptr_t);
    id _Nullable (^_onProvidingComposedString)(uintptr_t, uintptr_t);
    void (^_onAutoCommittingComposition)(uintptr_t, uintptr_t);
    NSUInteger (^_onProvidingRecognizedEvents)(uintptr_t, uintptr_t);
    BOOL (^_onHandlingGivenNullableEvent)(uintptr_t, uintptr_t, uintptr_t);
    void (^_onSettingObjCValue)(uintptr_t, intptr_t, uintptr_t, uintptr_t);
}

// MARK: - Block Properties (MRC)

#define MRC_BLOCK_PROPERTY(_name, _sig) \
    - (void)set##_name:(nullable _sig)block { \
        if (_##_name != block) { \
            [_##_name release]; \
            _##_name = [block copy]; \
        } \
    } \
    - (nullable _sig)_name { \
        return [[_##_name retain] autorelease]; \
    }

MRC_BLOCK_PROPERTY(onActivatingServer, void (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onDeactivatingServer, void (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onDealloc, void (^)(uintptr_t))
MRC_BLOCK_PROPERTY(onShowingPreferences, void (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onHidingPallettes, void (^)(uintptr_t))
MRC_BLOCK_PROPERTY(onInputControllerWillClose, void (^)(uintptr_t))
MRC_BLOCK_PROPERTY(onProvidingSelectionRange, NSRange (^)(uintptr_t))
MRC_BLOCK_PROPERTY(onProvidingIMEMenu, NSMenu * _Nullable (^)(uintptr_t))
MRC_BLOCK_PROPERTY(onProvidingComposedString, id _Nullable (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onAutoCommittingComposition, void (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onProvidingRecognizedEvents, NSUInteger (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onHandlingGivenNullableEvent, BOOL (^)(uintptr_t, uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onSettingObjCValue, void (^)(uintptr_t, intptr_t, uintptr_t, uintptr_t))

#undef MRC_BLOCK_PROPERTY

// MARK: - Lifecycle

- (void)dealloc {
    if (_onDealloc) _onDealloc((uintptr_t)self);
    [_onDealloc release];
    [_onActivatingServer release];
    [_onDeactivatingServer release];
    [_onShowingPreferences release];
    [_onHidingPallettes release];
    [_onInputControllerWillClose release];
    [_onProvidingSelectionRange release];
    [_onProvidingIMEMenu release];
    [_onProvidingComposedString release];
    [_onAutoCommittingComposition release];
    [_onProvidingRecognizedEvents release];
    [_onHandlingGivenNullableEvent release];
    [_onSettingObjCValue release];
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
    if (!ctls || [ctls count] <= 3) return;

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

    // Terminate the client wrapper associated with the stale controller
    // so that IMK's global wrapper cache and the underlying XPC connection
    // are released promptly. Otherwise the XPC connection outlives the
    // controller and accumulates as a leak.
    id clientProxy = [oldest client];
    if (clientProxy) {
        Class wrapperClass = NSClassFromString(@"IPMDServerClientWrapper");
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

    // Find the dictionary key for the oldest controller and remove it.
    for (id key in [ctls allKeys]) {
        if ([ctls objectForKey:key] == oldest) {
            [ctls removeObjectForKey:key];
            break;
        }
    }
}

// MARK: - Initializer

- (instancetype)initWithServer:(IMKServer *)server delegate:(nullable id)delegate client:(id)inputClient {
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self) {
        // Stamp this controller with a generation number for LRU tracking,
        // then prune stale controllers from IMKServer._controllers.
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

// MARK: - IMKInputController Overrides

- (void)activateServer:(id)sender {
    [self IMKSwift_cancelDelayedDealloc];
    // If blocks were released by a previous delayed-dealloc, re-inject the
    // init hook so that the controller becomes fully functional again.
    // IMKServer reuses controller instances from its internal _controllers
    // dictionary across activate/deactivate cycles.
    if (!_onActivatingServer) {
        SEL hookSel = @selector(onSuperConstructionSucceeded:delegate:client:);
        if ([self respondsToSelector:hookSel]) {
            NSMethodSignature *sig = [self methodSignatureForSelector:hookSel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setSelector:hookSel];
            [inv setTarget:self];
            id serverObj = self.server;
            id delegateObj = self.delegate;
            [inv setArgument:&serverObj atIndex:2];
            [inv setArgument:&delegateObj atIndex:3];
            [inv setArgument:&sender atIndex:4];
            [inv invoke];
        }
    }
    if (_onActivatingServer) _onActivatingServer((uintptr_t)sender, (uintptr_t)self);
}

- (void)deactivateServer:(id)sender {
    if (_onDeactivatingServer) _onDeactivatingServer((uintptr_t)sender, (uintptr_t)self);
    [self IMKSwift_scheduleDelayedDeallocAfterDelay:3.0];
}

- (void)showPreferences:(nullable id)sender {
    if (_onShowingPreferences) _onShowingPreferences((uintptr_t)sender, (uintptr_t)self);
}

- (void)hidePalettes {
    if (_onHidingPallettes) _onHidingPallettes((uintptr_t)self);
}

- (void)inputControllerWillClose {
    if (_onInputControllerWillClose) _onInputControllerWillClose((uintptr_t)self);
}

- (NSRange)selectionRange {
    if (_onProvidingSelectionRange) return _onProvidingSelectionRange((uintptr_t)self);
    return NSMakeRange(NSNotFound, 0);
}

- (nullable NSMenu *)menu {
    if (_onProvidingIMEMenu) return _onProvidingIMEMenu((uintptr_t)self);
    return [[NSMenu new] autorelease];
}

- (nullable id)composedString:(id)sender {
    if (_onProvidingComposedString) return _onProvidingComposedString((uintptr_t)sender, (uintptr_t)self);
    return nil;
}

- (void)commitComposition:(id)sender {
    if (_onAutoCommittingComposition) _onAutoCommittingComposition((uintptr_t)sender, (uintptr_t)self);
}

- (NSUInteger)recognizedEvents:(id)sender {
    if (_onProvidingRecognizedEvents) return _onProvidingRecognizedEvents((uintptr_t)sender, (uintptr_t)self);
    return 0;
}

- (BOOL)handleEvent:(nullable NSEvent *)event client:(id)sender {
    if (_onHandlingGivenNullableEvent) return _onHandlingGivenNullableEvent((uintptr_t)event, (uintptr_t)sender, (uintptr_t)self);
    return NO;
}

- (void)setValue:(nullable id)value forTag:(NSInteger)tag client:(id)sender {
    if (_onSettingObjCValue) _onSettingObjCValue((uintptr_t)value, (intptr_t)tag, (uintptr_t)sender, (uintptr_t)self);
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

/// Releases all block ivars and triggers the dealloc callback to unregister
/// from the leak tracker and clean up the associated InputSession.
///
/// The Objective-C object itself cannot be force-deallocated — IMKServer's
/// internal `_controllers` dictionary retains every controller indefinitely.
/// However, by releasing the blocks we give back the memory they occupy, and
/// `_onDealloc` ensures the Swift-side session and tracker entries are
/// cleaned up.  The remaining ObjC shell (~dozen ivar pointers) is negligible.
- (void)IMKSwift_delayedDealloc {
    if (_onDealloc) _onDealloc((uintptr_t)self);
    [_onDealloc release]; _onDealloc = nil;
    [_onActivatingServer release]; _onActivatingServer = nil;
    [_onDeactivatingServer release]; _onDeactivatingServer = nil;
    [_onShowingPreferences release]; _onShowingPreferences = nil;
    [_onHidingPallettes release]; _onHidingPallettes = nil;
    [_onInputControllerWillClose release]; _onInputControllerWillClose = nil;
    [_onProvidingSelectionRange release]; _onProvidingSelectionRange = nil;
    [_onProvidingIMEMenu release]; _onProvidingIMEMenu = nil;
    [_onProvidingComposedString release]; _onProvidingComposedString = nil;
    [_onAutoCommittingComposition release]; _onAutoCommittingComposition = nil;
    [_onProvidingRecognizedEvents release]; _onProvidingRecognizedEvents = nil;
    [_onHandlingGivenNullableEvent release]; _onHandlingGivenNullableEvent = nil;
    [_onSettingObjCValue release]; _onSettingObjCValue = nil;
}

@end

#pragma clang diagnostic pop

NS_ASSUME_NONNULL_END
