//
//  Copyright © 2018 PubNative. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "PNLite_KSCrashSentry_Deadlock.h"
#import "PNLite_KSCrashSentry_Private.h"
#include "PNLite_KSMach.h"

//#define PNLite_KSLogger_LocalLevel TRACE
#import "PNLite_KSLogger.h"

#define kPNLiteIdleInterval 5.0f

@class PNLite_KSCrashDeadlockMonitor;

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** Flag noting if we've installed our custom handlers or not.
 * It's not fully thread safe, but it's safer than locking and slightly better
 * than nothing.
 */
static volatile sig_atomic_t pnlite_g_installed = 0;

/** Thread which monitors other threads. */
static PNLite_KSCrashDeadlockMonitor *pnlite_g_monitor;

/** Context to fill with crash information. */
static PNLite_KSCrash_SentryContext *pnlite_g_context;

/** Interval between watchdog pulses. */
static NSTimeInterval pnlite_g_watchdogInterval = 0;

// ============================================================================
#pragma mark - X -
// ============================================================================

@interface PNLite_KSCrashDeadlockMonitor : NSObject

@property(nonatomic, readwrite, retain) NSThread *monitorThread;
@property(nonatomic, readwrite, assign) thread_t mainThread;
@property(atomic, readwrite, assign) BOOL awaitingResponse;

@end

@implementation PNLite_KSCrashDeadlockMonitor

@synthesize monitorThread = _monitorThread;
@synthesize mainThread = _mainThread;
@synthesize awaitingResponse = _awaitingResponse;

- (id)init {
    if ((self = [super init])) {
        // target (self) is retained until selector (runMonitor) exits.
        self.monitorThread =
            [[NSThread alloc] initWithTarget:self
                                    selector:@selector(runMonitor)
                                      object:nil];
        self.monitorThread.name = @"KSCrash Deadlock Detection Thread";
        [self.monitorThread start];

        dispatch_async(dispatch_get_main_queue(), ^{
          self.mainThread = pnlite_ksmachthread_self();
        });
    }
    return self;
}

- (void)cancel {
    [self.monitorThread cancel];
}

- (void)watchdogPulse {
    __block id blockSelf = self;
    self.awaitingResponse = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
      [blockSelf watchdogAnswer];
    });
}

- (void)watchdogAnswer {
    self.awaitingResponse = NO;
}

- (void)handleDeadlock {
    pnlite_kscrashsentry_beginHandlingCrash(pnlite_g_context);

    PNLite_KSLOG_DEBUG(@"Filling out context.");
    pnlite_g_context->crashType = PNLite_KSCrashTypeMainThreadDeadlock;
    pnlite_g_context->offendingThread = self.mainThread;
    pnlite_g_context->registersAreValid = false;

    PNLite_KSLOG_DEBUG(@"Calling main crash handler.");
    pnlite_g_context->onCrash();

    PNLite_KSLOG_DEBUG(@"Crash handling complete. Restoring original handlers.");
    pnlite_kscrashsentry_uninstall(PNLite_KSCrashTypeAll);

    PNLite_KSLOG_DEBUG(@"Calling abort()");
    abort();
}

- (void)runMonitor {
    BOOL cancelled = NO;
    do {
        // Only do a watchdog check if the watchdog interval is > 0.
        // If the interval is <= 0, just idle until the user changes it.
        @autoreleasepool {
            NSTimeInterval sleepInterval = pnlite_g_watchdogInterval;
            BOOL runWatchdogCheck = sleepInterval > 0;
            if (!runWatchdogCheck) {
                sleepInterval = kPNLiteIdleInterval;
            }
            [NSThread sleepForTimeInterval:sleepInterval];
            cancelled = self.monitorThread.isCancelled;
            if (!cancelled && runWatchdogCheck) {
                if (self.awaitingResponse) {
                    [self handleDeadlock];
                } else {
                    [self watchdogPulse];
                }
            }
        }
    } while (!cancelled);
}

@end

// ============================================================================
#pragma mark - API -
// ============================================================================

bool pnlite_kscrashsentry_installDeadlockHandler(
    PNLite_KSCrash_SentryContext *context) {
    PNLite_KSLOG_DEBUG(@"Installing deadlock handler.");
    if (pnlite_g_installed) {
        PNLite_KSLOG_DEBUG(@"Deadlock handler already installed.");
        return true;
    }
    pnlite_g_installed = 1;

    pnlite_g_context = context;

    PNLite_KSLOG_DEBUG(@"Creating new deadlock monitor.");
    pnlite_g_monitor = [[PNLite_KSCrashDeadlockMonitor alloc] init];
    return true;
}

void pnlite_kscrashsentry_uninstallDeadlockHandler(void) {
    PNLite_KSLOG_DEBUG(@"Uninstalling deadlock handler.");
    if (!pnlite_g_installed) {
        PNLite_KSLOG_DEBUG(@"Deadlock handler was already uninstalled.");
        return;
    }

    PNLite_KSLOG_DEBUG(@"Stopping deadlock monitor.");
    [pnlite_g_monitor cancel];
    pnlite_g_monitor = nil;

    pnlite_g_installed = 0;
}

void pnlite_kscrashsentry_setDeadlockHandlerWatchdogInterval(double value) {
    pnlite_g_watchdogInterval = value;
}
