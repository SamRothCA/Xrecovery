//
//  Utility.h
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/8/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//

#import <Foundation/Foundation.h>

enum UtilityTerminationReason {
    UtilityTerminationReasonExit = NSTaskTerminationReasonExit,
    UtilityTerminationReasonUncaughtSignal = NSTaskTerminationReasonUncaughtSignal,
};
typedef enum UtilityTerminationReason UtilityTerminationReason;

@interface Utility : NSObject

@property (copy) NSString *launchPath;
@property (copy) NSArray *arguments;
@property (copy) NSDictionary *environment;
@property (copy) NSString *currentDirectoryPath;

@property (readonly) int processIdentifier;
@property (readonly, getter=isRunning) BOOL running;

@property (readonly) int terminationStatus;
@property (readonly) UtilityTerminationReason terminationReason;

@property (readonly) NSString *output;
@property (readonly) id outputPropertyList;

@property (copy) void (^outputHandler)(NSString *outputLine);

@property (copy) void (^terminationHandler)(Utility *);

+ (Utility *)launchedUtilityWithLaunchPath:(NSString *)path
    arguments:(NSArray *)arguments;

- (void)launch;

- (void)kill:(int)signal;

- (BOOL)suspend;
- (BOOL)resume;

- (void)waitUntilExit;
- (BOOL)waitUntilExitBeforeDate:(NSDate *)date;

@end
