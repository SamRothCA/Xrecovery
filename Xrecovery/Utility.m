//
//  Utility.m
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/8/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//

#import "Utility.h"

@interface Utility ()

@property NSMutableData *outputData;
@property NSConditionLock *exitLock;

@end
@implementation Utility
{
    NSString *_output;
    id _plist;

    NSTask *_task;
}

+ (Utility *)launchedUtilityWithLaunchPath:(NSString *)path arguments:(NSArray *)arguments
{
    Utility *utility = [[self alloc] init];
    utility.launchPath = path;
    utility.arguments = arguments;
    [utility launch];
    [utility waitUntilExit];
    return utility;
}

- (id)init
{
    if (! (self = super.init)) return nil;

    _outputData = NSMutableData.data;
    _exitLock = [[NSConditionLock alloc] initWithCondition:0];

    _task = [[NSTask alloc] init];

    _output = nil;
    _plist = NSNull.null;

    // Create a pipe to which the task should send its output.
    NSPipe *outputPipe = NSPipe.pipe;
    _task.standardOutput = outputPipe;

    // Set the standard error to the null device.
    _task.standardError = NSFileHandle.fileHandleWithNullDevice;

    // Create a weak reference to ourselves for safe use within our handlers.
    __weak typeof(self) _self = self;

    // Set up a handler to run as the task outputs new data to the pipe.
    outputPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *outputFile)
    {
        // If an output handler has been set, process the data for it.
        if (_self.outputHandler)
        {
            // Decode the new output as UTF-8.
            NSString *outputLines = [[NSString alloc]
                initWithData:outputFile.availableData encoding:NSUTF8StringEncoding];
            // Run the handler for each line of the new output.
            [outputLines enumerateLinesUsingBlock:^(NSString *outputLine, BOOL *stop) {
                _self.outputHandler(outputLine);
            }];
        }
        // If there is no handler set, append the output to our total instead.
        else
            [_self.outputData appendData:outputFile.availableData];
    };

    // Create a handler to run when the task terminates.
    _task.terminationHandler = ^(NSTask *task)
    {
//        // Close the output pipe so that the output handler stops waiting for
//        // new data.
//        outputPipe.fileHandleForReading.readabilityHandler = nil;
//        [outputPipe.fileHandleForWriting closeFile];
//
        // Acquire the lock to unlock it with a value indicating we have exited.
        [_self.exitLock lock];
        [_self.exitLock unlockWithCondition:1];

        [_self didChangeValueForKey:@"processIdentifier"];
        [_self didChangeValueForKey:@"running"];

        [_self didChangeValueForKey:@"terminationReason"];
        [_self didChangeValueForKey:@"terminationStatus"];

        [_self didChangeValueForKey:@"output"];
        [_self didChangeValueForKey:@"outputPropertyList"];

        // If a termination handler was set, run it now.
        if (_self.terminationHandler)
            _self.terminationHandler(_self);
    };


    return self;
}

- (NSString *)output
{
    if (! self.exitLock.condition)
        [NSException raise:NSInvalidArgumentException format:@"Utility has not finished running."];

    // Decode the output as UTF-8 if we have not done so already.
    if (! _output)
        _output = [[NSString alloc] initWithData:self.outputData encoding:NSUTF8StringEncoding];

    return _output;
}

- (id)outputPropertyList
{
    if (! self.exitLock.condition)
        [NSException raise:NSInvalidArgumentException format:@"Utility has not finished running."];

    // Attempt to interpret a property list object from the output data if we
    // have not done so already.
    if (_plist == NSNull.null)
        _plist = (__bridge id)CFPropertyListCreateFromXMLData(
            NULL,
            (__bridge CFDataRef)self.outputData,
            kCFPropertyListImmutable,
            NULL
        );

    // If the interpretation was successful, return the object.
    return _plist;
}

- (NSString *)launchPath { return _task.launchPath; }
- (void)setLaunchPath:(NSString *)launchPath {
    _task.launchPath = launchPath;
}

- (NSArray *)arguments { return _task.arguments; }
- (void)setArguments:(NSArray *)arguments {
    _task.arguments = arguments;
}

- (NSDictionary *)environment { return _task.environment; }
- (void)setEnvironment:(NSDictionary *)environment {
    _task.environment = environment;
}
- (NSString *)currentDirectoryPath { return _task.currentDirectoryPath; }
- (void)setCurrentDirectoryPath:(NSString *)currentDirectoryPath {
    _task.currentDirectoryPath = currentDirectoryPath;
}

- (int)processIdentifier { return _task.processIdentifier; }
- (BOOL)isRunning { return _task.running; }

- (int)terminationStatus { return _task.terminationStatus; }
- (UtilityTerminationReason) terminationReason
{
    switch (_task.terminationReason)
    {
        case NSTaskTerminationReasonExit: return UtilityTerminationReasonExit;
        case NSTaskTerminationReasonUncaughtSignal: return UtilityTerminationReasonUncaughtSignal;
    }
}

- (void)launch
{
    [_task launch];
    [self didChangeValueForKey:@"running"];
    [self didChangeValueForKey:@"processIdentifier"];
}

- (void)kill:(int)signal {
    kill(_task.processIdentifier, signal);
}

- (BOOL)suspend { return [_task suspend]; }
- (BOOL)resume { return [_task resume]; }

- (void)waitUntilExit
{
    [_exitLock lockWhenCondition:1];
    [_exitLock unlock];
}
- (BOOL)waitUntilExitBeforeDate:(NSDate *)date
{
    BOOL result = [_exitLock lockWhenCondition:1 beforeDate:date];

    if (result)
        [_exitLock unlock];

    return result;
}

@end
