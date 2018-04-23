//
//  BugsnagCrashReport.h
//  Bugsnag
//
//  Created by Simon Maynard on 11/26/14.
//
//

#import <Foundation/Foundation.h>

@class BugsnagConfiguration;
@class BugsnagHandledState;
@class PNLiteSession;

typedef NS_ENUM(NSUInteger, BSGSeverity) {
    BSGSeverityError,
    BSGSeverityWarning,
    BSGSeverityInfo,
};

/**
 *  Convert a string to a severity value
 *
 *  @param severity Intended severity value, such as info, warning, or error
 *
 *  @return converted severity level or BSGSeverityError if no conversion is
 * found
 */
BSGSeverity BSGParseSeverity(NSString *_Nonnull severity);

/**
 *  Serialize a severity for JSON payloads
 *
 *  @param severity a severity
 *
 *  @return the equivalent string value
 */
NSString *_Nonnull BSGFormatSeverity(BSGSeverity severity);

@interface BugsnagCrashReport : NSObject

/**
 *  Create a new crash report from a JSON crash report generated by
 * BugsnagCrashSentry
 *
 *  @param report a BugsnagCrashSentry JSON report
 *
 *  @return a Bugsnag crash report
 */
- (instancetype _Nonnull)initWithKSReport:(NSDictionary *_Nonnull)report;

/**
 *  Create a basic crash report from raw parts.
 *
 *  Assumes that the exception is handled.
 *
 *  @param name      The name of the exception
 *  @param message   The reason or message from the exception
 *  @param config    Bugsnag configuration
 *  @param metaData  additional data to attach to the report
 *  @param handledState  the handled state of the error
 *
 *  @return a Bugsnag crash report
 */
- (instancetype _Nonnull)
initWithErrorName:(NSString *_Nonnull)name
     errorMessage:(NSString *_Nonnull)message
    configuration:(BugsnagConfiguration *_Nonnull)config
         metaData:(NSDictionary *_Nonnull)metaData
     handledState:(BugsnagHandledState *_Nonnull)handledState
          session:(PNLiteSession *_Nullable)session;

/**
 *  Serialize a crash report as a JSON payload
 *
 *  @param data top level report data, may need to be modified based on
 * environment
 *
 *  @return a crash report
 */
- (NSDictionary *_Nonnull)serializableValueWithTopLevelData:
    (NSMutableDictionary *_Nonnull)data
__deprecated_msg("Use toJson: instead.");

- (NSDictionary *_Nonnull)toJson;

/**
 *  Whether this report should be sent, based on release stage information
 *  cached at crash time and within the application currently
 *
 *  @return YES if the report should be sent
 */
- (BOOL)shouldBeSent;

/**
 *  Prepend a custom stacktrace with a provided type to the crash report
 */
- (void)attachCustomStacktrace:(NSArray *_Nonnull)frames
                      withType:(NSString *_Nonnull)type;

/**
 * Add metadata to a report to a tab. If the tab does not exist, it will be
 * added.
 *
 * @param metadata The key/value pairs to add
 * @param tabName  The name of the report section
 */
- (void)addMetadata:(NSDictionary *_Nonnull)metadata
      toTabWithName:(NSString *_Nonnull)tabName;

/**
 * Add or remove a value from report metadata. If value is nil, the existing
 value
 * will be removed.

 @param attributeName The key name
 @param value The value to set
 @param tabName The name of the report section
 */
- (void)addAttribute:(NSString *_Nonnull)attributeName
           withValue:(id _Nullable)value
       toTabWithName:(NSString *_Nonnull)tabName;

/**
 *  The release stages used to notify at the time this report is captured
 */
@property(readwrite, copy, nullable) NSArray *notifyReleaseStages;
/**
 *  A loose representation of what was happening in the application at the time
 *  of the event
 */
@property(readwrite, copy, nullable) NSString *context;
/**
 *  The severity of the error generating the report
 */
@property(readwrite) BSGSeverity severity;
/**
 *  The release stage of the application
 */
@property(readwrite, copy, nullable) NSString *releaseStage;
/**
 *  The class of the error generating the report
 */
@property(readwrite, copy, nonnull) NSString *errorClass;
/**
 *  The message of or reason for the error generating the report
 */
@property(readwrite, copy, nullable) NSString *errorMessage;
/**
 *  Customized hash for grouping this report with other errors
 */
@property(readwrite, copy, nullable) NSString *groupingHash;
/**
 *  Breadcrumbs from user events leading up to the error
 */
@property(readwrite, copy, nullable) NSArray *breadcrumbs;
/**
 *  Further information attached to an error report, where each top level key
 *  generates a section on bugsnag, displaying key/value pairs
 */
@property(readwrite, copy, nonnull) NSDictionary *metaData;
/**
 *  The event state (whether the error is handled/unhandled)
 */
@property(readonly, nonnull) BugsnagHandledState *handledState;

/**
 *  Property overrides
 */
@property(readonly, copy, nonnull) NSDictionary *overrides;
/**
 *  Number of frames to discard at the top of the stacktrace
 */
@property(readwrite) NSUInteger depth;
/**
 *  Raw error data
 */
@property(readwrite, copy, nullable) NSDictionary *error;
/**
 *  Device information such as OS name and version
 */
@property(readwrite, copy, nullable) NSDictionary *device;
/**
 *  Device state such as memory allocation at crash time
 */
@property(readwrite, copy, nullable) NSDictionary *deviceState;
/**
 *  App information such as the name, version, and bundle ID
 */
@property(readwrite, copy, nullable) NSDictionary *app;
/**
 *  Device state such as oreground status and run duration
 */
@property(readwrite, copy, nullable) NSDictionary *appState;


/**
 * Returns the enhanced error message for the thread, or nil if none exists.
 */
- (NSString *_Nullable)enhancedErrorMessageForThread:(NSDictionary *_Nullable)thread __deprecated;

@end
