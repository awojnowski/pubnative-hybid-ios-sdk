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

#import "PNLite_KSCrashAdvanced.h"

#import "PNLite_KSCrashC.h"
#import "PNLite_KSCrashCallCompletion.h"
#import "PNLite_KSJSONCodecObjC.h"
#import "PNLite_KSSingleton.h"
#import "PNLite_KSSystemCapabilities.h"
#import "NSError+PNLite_SimpleConstructor.h"

//#define PNLite_KSLogger_LocalLevel TRACE
#import "PNLite_KSLogger.h"

#if PNLite_KSCRASH_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

// ============================================================================
#pragma mark - Default Constants -
// ============================================================================

/** The directory under "Caches" to store the crash reports. */
#ifndef PNLite_KSCRASH_DefaultReportFilesDirectory
#define PNLite_KSCRASH_DefaultReportFilesDirectory @"PNLiteKSCrashReports"
#endif

// ============================================================================
#pragma mark - Constants -
// ============================================================================

#define PNLite_kCrashLogFilenameSuffix "-PNLiteCrashLog.txt"
#define PNLite_kCrashStateFilenameSuffix "-PNLiteCrashState.json"

// ============================================================================
#pragma mark - Globals -
// ============================================================================

@interface PNLite_KSCrash ()

@property(nonatomic, readwrite, retain) NSString *bundleName;
@property(nonatomic, readwrite, retain) NSString *nextCrashID;
@property(nonatomic, readonly, retain) NSString *crashReportPath;
@property(nonatomic, readonly, retain) NSString *recrashReportPath;
@property(nonatomic, readonly, retain) NSString *stateFilePath;

// Mirrored from PNLite_KSCrashAdvanced.h to provide ivars
@property(nonatomic, readwrite, retain) id<PNLite_KSCrashReportFilter> sink;
@property(nonatomic, readwrite, retain) NSString *logFilePath;
@property(nonatomic, readwrite, retain)
    PNLite_KSCrashReportStore *crashReportStore;
@property(nonatomic, readwrite, assign) PNLite_KSReportWriteCallback onCrash;
@property(nonatomic, readwrite, assign) bool printTraceToStdout;
@property(nonatomic, readwrite, assign) int maxStoredReports;

@end

@implementation PNLite_KSCrash

// ============================================================================
#pragma mark - Properties -
// ============================================================================

@synthesize sink = _sink;
@synthesize userInfo = _userInfo;
@synthesize deleteBehaviorAfterSendAll = _deleteBehaviorAfterSendAll;
@synthesize handlingCrashTypes = _handlingCrashTypes;
@synthesize deadlockWatchdogInterval = _deadlockWatchdogInterval;
@synthesize printTraceToStdout = _printTraceToStdout;
@synthesize onCrash = _onCrash;
@synthesize crashReportStore = _crashReportStore;
@synthesize bundleName = _bundleName;
@synthesize logFilePath = _logFilePath;
@synthesize nextCrashID = _nextCrashID;
@synthesize searchThreadNames = _searchThreadNames;
@synthesize searchQueueNames = _searchQueueNames;
@synthesize introspectMemory = _introspectMemory;
@synthesize catchZombies = _catchZombies;
@synthesize doNotIntrospectClasses = _doNotIntrospectClasses;
@synthesize maxStoredReports = _maxStoredReports;
@synthesize suspendThreadsForUserReported = _suspendThreadsForUserReported;
@synthesize reportWhenDebuggerIsAttached = _reportWhenDebuggerIsAttached;
@synthesize threadTracingEnabled = _threadTracingEnabled;
@synthesize writeBinaryImagesForUserReported =
    _writeBinaryImagesForUserReported;

// ============================================================================
#pragma mark - Lifecycle -
// ============================================================================

- (void)setDemangleLanguages:(PNLite_KSCrashDemangleLanguage)demangleLanguages {
    self.crashReportStore.demangleCPP =
        (demangleLanguages & PNLite_KSCrashDemangleLanguageCPlusPlus) != 0;
    self.crashReportStore.demangleSwift =
        (demangleLanguages & PNLite_KSCrashDemangleLanguageSwift) != 0;
}

- (PNLite_KSCrashDemangleLanguage)demangleLanguages {
    PNLite_KSCrashDemangleLanguage languages = 0;
    if (self.crashReportStore.demangleCPP) {
        languages |= PNLite_KSCrashDemangleLanguageCPlusPlus;
    }
    if (self.crashReportStore.demangleSwift) {
        languages |= PNLite_KSCrashDemangleLanguageSwift;
    }
    return languages;
}

IMPLEMENT_EXCLUSIVE_SHARED_INSTANCE(PNLite_KSCrash)

- (id)init {
    return [self
        initWithReportFilesDirectory:PNLite_KSCRASH_DefaultReportFilesDirectory];
}

- (id)initWithReportFilesDirectory:(NSString *)reportFilesDirectory {
    if ((self = [super init])) {
        self.bundleName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];

        NSString *storePath = [PNLiteFileStore findReportStorePath:reportFilesDirectory
                                                         bundleName:self.bundleName];

        if (!storePath) {
            PNLite_KSLOG_ERROR(
                    @"Failed to initialize crash handler. Crash reporting disabled.");
            return nil;
        }

        self.nextCrashID = [NSUUID UUID].UUIDString;
        self.crashReportStore = [PNLite_KSCrashReportStore storeWithPath:storePath];
        self.deleteBehaviorAfterSendAll = PNLite_KSCDeleteAlways;
        self.searchThreadNames = NO;
        self.searchQueueNames = NO;
        self.introspectMemory = YES;
        self.catchZombies = NO;
        self.maxStoredReports = 5;

        self.suspendThreadsForUserReported = YES;
        self.reportWhenDebuggerIsAttached = NO;
        self.threadTracingEnabled = YES;
        self.writeBinaryImagesForUserReported = YES;
    }
    return self;
}

// ============================================================================
#pragma mark - API -
// ============================================================================

- (void)setUserInfo:(NSDictionary *)userInfo {
    NSError *error = nil;
    NSData *userInfoJSON = nil;
    if (userInfo != nil) {
        userInfoJSON = [self
            nullTerminated:[PNLite_KSJSONCodec encode:userInfo
                                           options:PNLite_KSJSONEncodeOptionSorted
                                             error:&error]];
        if (error != NULL) {
            PNLite_KSLOG_ERROR(@"Could not serialize user info: %@", error);
            return;
        }
    }

    _userInfo = userInfo;
    pnlite_kscrash_setUserInfoJSON([userInfoJSON bytes]);
}

- (void)setHandlingCrashTypes:(PNLite_KSCrashType)handlingCrashTypes {
    _handlingCrashTypes = pnlite_kscrash_setHandlingCrashTypes(handlingCrashTypes);
}

- (void)setDeadlockWatchdogInterval:(double)deadlockWatchdogInterval {
    _deadlockWatchdogInterval = deadlockWatchdogInterval;
    pnlite_kscrash_setDeadlockWatchdogInterval(deadlockWatchdogInterval);
}

- (void)setPrintTraceToStdout:(bool)printTraceToStdout {
    _printTraceToStdout = printTraceToStdout;
    pnlite_kscrash_setPrintTraceToStdout(printTraceToStdout);
}

- (void)setOnCrash:(PNLite_KSReportWriteCallback)onCrash {
    _onCrash = onCrash;
    pnlite_kscrash_setCrashNotifyCallback(onCrash);
}

- (void)setSearchThreadNames:(bool)searchThreadNames {
    _searchThreadNames = searchThreadNames;
    pnlite_kscrash_setSearchThreadNames(searchThreadNames);
}

- (void)setSearchQueueNames:(bool)searchQueueNames {
    _searchQueueNames = searchQueueNames;
    pnlite_kscrash_setSearchQueueNames(searchQueueNames);
}

- (void)setIntrospectMemory:(bool)introspectMemory {
    _introspectMemory = introspectMemory;
    pnlite_kscrash_setIntrospectMemory(introspectMemory);
}

- (void)setCatchZombies:(bool)catchZombies {
    _catchZombies = catchZombies;
    pnlite_kscrash_setCatchZombies(catchZombies);
}

- (void)setSuspendThreadsForUserReported:(BOOL)suspendThreadsForUserReported {
    _suspendThreadsForUserReported = suspendThreadsForUserReported;
    pnlite_kscrash_setSuspendThreadsForUserReported(suspendThreadsForUserReported);
}

- (void)setReportWhenDebuggerIsAttached:(BOOL)reportWhenDebuggerIsAttached {
    _reportWhenDebuggerIsAttached = reportWhenDebuggerIsAttached;
    pnlite_kscrash_setReportWhenDebuggerIsAttached(reportWhenDebuggerIsAttached);
}

- (void)setThreadTracingEnabled:(BOOL)threadTracingEnabled {
    _threadTracingEnabled = threadTracingEnabled;
    pnlite_kscrash_setThreadTracingEnabled(threadTracingEnabled);
}

- (void)setWriteBinaryImagesForUserReported:
    (BOOL)writeBinaryImagesForUserReported {
    _writeBinaryImagesForUserReported = writeBinaryImagesForUserReported;
    pnlite_kscrash_setWriteBinaryImagesForUserReported(
        writeBinaryImagesForUserReported);
}

- (void)setDoNotIntrospectClasses:(NSArray *)doNotIntrospectClasses {
    _doNotIntrospectClasses = doNotIntrospectClasses;
    size_t count = [doNotIntrospectClasses count];
    if (count == 0) {
        pnlite_kscrash_setDoNotIntrospectClasses(nil, 0);
    } else {
        NSMutableData *data =
            [NSMutableData dataWithLength:count * sizeof(const char *)];
        const char **classes = data.mutableBytes;
        for (size_t i = 0; i < count; i++) {
            classes[i] = [doNotIntrospectClasses[i]
                cStringUsingEncoding:NSUTF8StringEncoding];
        }
        pnlite_kscrash_setDoNotIntrospectClasses(classes, count);
    }
}

- (NSString *)crashReportPath {
    return [self.crashReportStore pathToFileWithId:self.nextCrashID];
}

- (NSString *)recrashReportPath {
    return [self.crashReportStore pathToRecrashReportWithID:self.nextCrashID];
}

- (NSString *)stateFilePath {
    NSString *stateFilename = [NSString
        stringWithFormat:@"%@" PNLite_kCrashStateFilenameSuffix, self.bundleName];
    return [self.crashReportStore.path
        stringByAppendingPathComponent:stateFilename];
}

- (BOOL)install {
    _handlingCrashTypes = pnlite_kscrash_install(
        [self.crashReportPath UTF8String], [self.recrashReportPath UTF8String],
        [self.stateFilePath UTF8String], [self.nextCrashID UTF8String]);
    if (self.handlingCrashTypes == 0) {
        return false;
    }

#if PNLite_KSCRASH_HAS_UIKIT
    NSNotificationCenter *nCenter = [NSNotificationCenter defaultCenter];
    [nCenter addObserver:self
                selector:@selector(applicationDidBecomeActive)
                    name:UIApplicationDidBecomeActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillResignActive)
                    name:UIApplicationWillResignActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationDidEnterBackground)
                    name:UIApplicationDidEnterBackgroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillEnterForeground)
                    name:UIApplicationWillEnterForegroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillTerminate)
                    name:UIApplicationWillTerminateNotification
                  object:nil];
#endif

    return true;
}

- (void)sendAllReportsWithCompletion:
    (PNLite_KSCrashReportFilterCompletion)onCompletion {
    [self.crashReportStore pruneFilesLeaving:self.maxStoredReports];

    NSArray *reports = [self allReports];

    PNLite_KSLOG_INFO(@"Sending %d crash reports", [reports count]);

    [self sendReports:reports
         onCompletion:^(NSArray *filteredReports, BOOL completed,
                        NSError *error) {
           PNLite_KSLOG_DEBUG(@"Process finished with completion: %d", completed);
           if (error != nil) {
               PNLite_KSLOG_ERROR(@"Failed to send reports: %@", error);
           }
           if ((self.deleteBehaviorAfterSendAll == PNLite_KSCDeleteOnSucess &&
                completed) ||
               self.deleteBehaviorAfterSendAll == PNLite_KSCDeleteAlways) {
               [self deleteAllReports];
           }
           pnlite_kscrash_i_callCompletion(onCompletion, filteredReports,
                                        completed, error);
         }];
}

- (void)deleteAllReports {
    [self.crashReportStore deleteAllFiles];
}

- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
                   language:(NSString *)language
                 lineOfCode:(NSString *)lineOfCode
                 stackTrace:(NSArray *)stackTrace
           terminateProgram:(BOOL)terminateProgram {
    const char *cName = [name cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cReason = [reason cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cLanguage =
        [language cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cLineOfCode =
        [lineOfCode cStringUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *jsonData =
        [PNLite_KSJSONCodec encode:stackTrace options:0 error:&error];
    if (jsonData == nil || error != nil) {
        PNLite_KSLOG_ERROR(@"Error encoding stack trace to JSON: %@", error);
        // Don't return, since we can still record other useful information.
    }
    NSString *jsonString =
        [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    const char *cStackTrace =
        [jsonString cStringUsingEncoding:NSUTF8StringEncoding];

    pnlite_kscrash_reportUserException(cName, cReason, cLanguage, cLineOfCode,
                                    cStackTrace, terminateProgram);

    // If pnlite_kscrash_reportUserException() returns, we did not terminate.
    // Set up IDs and paths for the next crash.

    self.nextCrashID = [NSUUID UUID].UUIDString;

    pnlite_kscrash_reinstall(
        [self.crashReportPath UTF8String], [self.recrashReportPath UTF8String],
        [self.stateFilePath UTF8String], [self.nextCrashID UTF8String]);
}

// ============================================================================
#pragma mark - Advanced API -
// ============================================================================

#define PNLite_SYNTHESIZE_CRASH_STATE_PROPERTY(TYPE, NAME)                        \
    -(TYPE)NAME {                                                              \
        return pnlite_kscrashstate_currentState()->NAME;                          \
    }

PNLite_SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval,
                                    activeDurationSinceLastCrash)
PNLite_SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval,
                                    backgroundDurationSinceLastCrash)
PNLite_SYNTHESIZE_CRASH_STATE_PROPERTY(int, launchesSinceLastCrash)
PNLite_SYNTHESIZE_CRASH_STATE_PROPERTY(int, sessionsSinceLastCrash)
PNLite_SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, activeDurationSinceLaunch)
PNLite_SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval,
                                    backgroundDurationSinceLaunch)
PNLite_SYNTHESIZE_CRASH_STATE_PROPERTY(int, sessionsSinceLaunch)
PNLite_SYNTHESIZE_CRASH_STATE_PROPERTY(BOOL, crashedLastLaunch)

- (NSUInteger)reportCount {
    return [self.crashReportStore fileCount];
}

- (NSString *)crashReportsPath {
    return self.crashReportStore.path;
}

- (void)sendReports:(NSArray *)reports
       onCompletion:(PNLite_KSCrashReportFilterCompletion)onCompletion {
    if ([reports count] == 0) {
        pnlite_kscrash_i_callCompletion(onCompletion, reports, YES, nil);
        return;
    }

    if (self.sink == nil) {
        pnlite_kscrash_i_callCompletion(
            onCompletion, reports, NO,
            [NSError pnlite_errorWithDomain:[[self class] description]
                                    code:0
                             description:@"No sink set. Crash reports not sent."]);
        return;
    }

    [self.sink filterReports:reports
                onCompletion:^(NSArray *filteredReports, BOOL completed,
                               NSError *error) {
                  pnlite_kscrash_i_callCompletion(onCompletion, filteredReports,
                                               completed, error);
                }];
}

- (NSArray *)allReports {
    return [self.crashReportStore allFiles];
}

- (BOOL)redirectConsoleLogsToFile:(NSString *)fullPath
                        overwrite:(BOOL)overwrite {
    if (pnlite_kslog_setLogFilename([fullPath UTF8String], overwrite)) {
        self.logFilePath = fullPath;
        return YES;
    }
    return NO;
}

- (BOOL)redirectConsoleLogsToDefaultFile {
    NSString *logFilename = [NSString
        stringWithFormat:@"%@" PNLite_kCrashLogFilenameSuffix, self.bundleName];
    NSString *logFilePath =
        [self.crashReportStore.path stringByAppendingPathComponent:logFilename];
    if (![self redirectConsoleLogsToFile:logFilePath overwrite:YES]) {
        PNLite_KSLOG_ERROR(@"Could not redirect logs to %@", logFilePath);
        return NO;
    }
    return YES;
}

// ============================================================================
#pragma mark - Utility -
// ============================================================================


- (NSMutableData *)nullTerminated:(NSData *)data {
    if (data == nil) {
        return NULL;
    }
    NSMutableData *mutable = [NSMutableData dataWithData:data];
    [mutable appendBytes:"\0" length:1];
    return mutable;
}

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

- (void)applicationDidBecomeActive {
    pnlite_kscrashstate_notifyAppActive(true);
}

- (void)applicationWillResignActive {
    pnlite_kscrashstate_notifyAppActive(false);
}

- (void)applicationDidEnterBackground {
    pnlite_kscrashstate_notifyAppInForeground(false);
}

- (void)applicationWillEnterForeground {
    pnlite_kscrashstate_notifyAppInForeground(true);
}

- (void)applicationWillTerminate {
    pnlite_kscrashstate_notifyAppTerminate();
}

@end

//! Project version number for PNLite_KSCrashFramework.
const double PNLite_KSCrashFrameworkVersionNumber = 1.813;

//! Project version string for PNLite_KSCrashFramework.
const unsigned char PNLite_KSCrashFrameworkVersionString[] = "1.8.13";
