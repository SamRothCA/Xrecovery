//
//  SystemTransfer.m
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/7/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//


@interface SystemTransfer ()

@property Utility *utility;
@property BOOL completed;
@property NSUInteger bytesCompleted;

@end
@implementation SystemTransfer

- (void)enterStage
{
    // Initialize the asr task and our completion status.
    self.utility = nil;
    self.completed = NO;

    // Initialize the progress display.
    self.progressIndicator.doubleValue = 0.0;
    self.progressIndicator.hidden = YES;
    self.progressLabel.stringValue = [NSString stringWithFormat:
        @"Click Begin to apply recovery system “%@” to disk “%@”",
        self.source.label, self.destination.label
    ];

    // Enable the continue button, and set its title for the upcoming transfer.
    app.backButton.title = @"Back";
    app.continueButton.title = @"Begin";
    app.continueButton.enabled = YES;
}

- (void)leaveStage
{
    // Restore the Continue and Back buttons' titles.
    app.continueButton.title = @"Continue";
    app.backButton.title = @"Back";
}

- (void)backAction
{
    // If the task is running and the back button is clicked, display a modal
    // confirmation
    if (self.utility && self.utility.running)
    {
        self.confirmationHeader.stringValue =
            @"Are you sure you want to cancel the conversion?";
        self.confirmationDetails.stringValue =
            @"Any progress made in transferring the recovery system will be lost.";
        self.confirmationProceed.title = @"Abort";

        [NSApp beginSheet:self.confirmationWindow modalForWindow:app.window
            modalDelegate:self didEndSelector:nil contextInfo:nil];
    }
    // If the task hasn't been started yet, return to the destination selection.
    else {
        app.stage = destinations;
    }
}

- (void)continueAction
{
    // If the continue button is clicked, and the task has been run, set our
    // bullet in the checklist to indicate this stage's uncompletion, then go on
    // to the option selection stage.
    if (self.completed)
    {
        app.transferSystemImage.image = [NSImage imageNamed:NSImageNameStatusAvailable];
//        app.stage = optionsSelection;
    }

    // Upon clicking the continue button when the transfer has not yet been run,
    // display the confirmation panel to warn of the destination's erasure.
    else {
        self.confirmationHeader.stringValue = [NSString stringWithFormat:
            @"Are you sure you want to convert the disk “%@”?", self.destination.label];
        self.confirmationDetails.stringValue =
            @"Converting the disk to a recovery system erases all of its contents. This cannot be undone.";
        self.confirmationProceed.title = @"Proceed";

        [NSApp beginSheet:self.confirmationWindow modalForWindow:app.window
            modalDelegate:self didEndSelector:nil contextInfo:nil];
    }
}


- (void)displayDissenter:(DADissenterRef)dissenter format:(NSString *)format, ...
{
    // Hide the progress bar and revert the back and continue buttons.
    self.progressIndicator.hidden = YES;
    app.backButton.title = @"Back";
    app.continueButton.title = @"Begin";
    app.continueButton.enabled = YES;

    // Format the provided arguments for the primary error description.
    va_list arguments;
    va_start(arguments, format);
    NSMutableString *error = [[NSMutableString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);

    // If we were passed a dissenter, append its string to the error.
//    if (dissenter)
//    {
//        DAReturn status = DADissenterGetStatus(dissenter);
//        CFStringRef statusString = DADissenterGetStatusString(dissenter);
//        if (! statusString)
//            switch (status)
//            {
//                case kDAReturnError           : statusString = CFSTR( "kDAReturnError"           ); break;
//                case kDAReturnBusy            : statusString = CFSTR( "kDAReturnBusy"            ); break;
//                case kDAReturnBadArgument     : statusString = CFSTR( "kDAReturnBadArgument"     ); break;
//                case kDAReturnExclusiveAccess : statusString = CFSTR( "kDAReturnExclusiveAccess" ); break;
//                case kDAReturnNoResources     : statusString = CFSTR( "kDAReturnNoResources"     ); break;
//                case kDAReturnNotFound        : statusString = CFSTR( "kDAReturnNotFound"        ); break;
//                case kDAReturnNotMounted      : statusString = CFSTR( "kDAReturnNotMounted"      ); break;
//                case kDAReturnNotPermitted    : statusString = CFSTR( "kDAReturnNotPermitted"    ); break;
//                case kDAReturnNotPrivileged   : statusString = CFSTR( "kDAReturnNotPrivileged"   ); break;
//                case kDAReturnNotReady        : statusString = CFSTR( "kDAReturnNotReady"        ); break;
//                case kDAReturnNotWritable     : statusString = CFSTR( "kDAReturnNotWritable"     ); break;
//                case kDAReturnUnsupported     : statusString = CFSTR( "kDAReturnUnsupported"     ); break;
//            }
//        [error appendFormat:@" %@.", (__bridge NSString *)statusString];
//    }

    // Display the finished error.
    self.progressLabel.stringValue = error;

    // Clean up any resources we are using.
    [self detachInstallESD];
    [self.source unmount];
    [self.destination unmount];
    self.destination.exclusiveAccess = NO;
}

- (IBAction)confirmationCancel:(id)sender
{
    // If the Cancel button was chosen, simply hide the panel.
    [NSApp endSheet:self.confirmationWindow];
    [self.confirmationWindow orderOut:sender];
}

- (IBAction)confirmationProceed:(id)sender
{
    // If the proceed button was chosen in the confirmation panel, hide the
    // panel, then proceed as the conditions dictate.
    [NSApp endSheet:self.confirmationWindow];
    [self.confirmationWindow orderOut:sender];

    // If the panel was shown to abort the transfer, terminate the current task.
    if (self.utility) {
        self.utility.terminationHandler = nil;
        [self.utility kill:SIGINT];
        [self.utility waitUntilExit];
        self.utility = nil;
        // Reset the progress display.
        [self enterStage];
    }

    // Otherwise, the panel was shown to confirm the start of the transfer, so
    // we may now begin.
    else {
        // Restore the Continue button's title, but disable it.
        app.continueButton.title = @"Continue";
        app.continueButton.enabled = NO;
        // Change the Back button to indicate its new Abort action.
        app.backButton.title = @"Abort";

        // Set up the progress display.
        self.progressIndicator.hidden = NO;
        [self.progressIndicator startAnimation:nil];

        // If we are working with an installer, start by attaching its image.
        if (self.source.installESDPath)
            [self attachInstallESD];
        // Otherwise, go straight to restoring the BaseSystem.dmg.
        else
            [self createBaseSystem];
    }
}

- (void)attachInstallESD
{
    // Present the fact that we are verifying the disk image.
    self.progressLabel.stringValue = @"Verifying installer image.";

    // Set up the progress bar with a range of 0 to 100.
    self.progressIndicator.minValue = 0.0;
    self.progressIndicator.maxValue = 100.0;
    self.progressIndicator.doubleValue = 0.0;

    // Begin a task object for directing hdiutil to attach the image for us.
    self.utility = [[Utility alloc] init];
    self.utility.launchPath = @"/usr/bin/hdiutil";
    self.utility.arguments =
    @[
        @"attach", self.source.installESDPath,
        // Do not mount the attached image; we will be doing this ourselves.
        @"-nomount",
        // Return output in parseable format.
        @"-puppetstrings",

        @"-noverify"
    ];

    // Set up a weak reference to ourselves for use in blocks.
    __weak typeof(self) _self = self;

    // Create a handler to monitor hdiutil's verification of the disk image.
    self.utility.outputHandler = ^(NSString *outputLine)
    {
        // A colon in the output line divides the line's key and value.
        NSUInteger valueOffset = [outputLine rangeOfString:@":"].location;
        if (valueOffset != NSNotFound)
        {
            // If the line's key denotes the progress of the verification, set
            // that percentage as the progress bar's value.
            if ([[outputLine substringToIndex:valueOffset] isEqualToString:@"PERCENT"])
            {
                NSString *value = [outputLine substringFromIndex:valueOffset + 1];
                _self.progressIndicator.doubleValue = value.doubleValue;
            }
        }

        // If the line of output begins with a device path, the image has passed
        // verification.
        else if ([outputLine hasPrefix:@"/dev/disk"])
        {
            // Whitespace in the output line separates the device path from the
            // its partition type.
            NSRange outputSpacing = [outputLine
                rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet];

            // Create a range of characters which skips the "/dev/" at the
            // beginning of the device path.
            NSRange BSDNameRange = NSMakeRange(5, outputSpacing.location - 5);

            // Set partitions as the source's BSD name as they appear.
            _self.source.BSDName = [outputLine substringWithRange:BSDNameRange];
        }
    };

    // Create a handler to process the results of the attach attempt.
    self.utility.terminationHandler = ^(Utility *utility)
    {
        // If we've successfully attached the disk image, proceed to run asr.
        if (_self.source.BSDName)
            [_self createBaseSystem];

        // If we couldn't attach the disk image, present the error.
        else
            [_self displayDissenter:NULL format:@"Failed to verify installer image."];
    };

    [self.utility launch];
}

- (void)createBaseSystem
{
    self.progressLabel.stringValue = @"Restoring Base System";

    // Set up the progress bar with a range of 0 to 100.
    self.progressIndicator.minValue = 0.0;
    self.progressIndicator.maxValue = 100.0;
    self.progressIndicator.doubleValue = 0.0;

    // Attempt to mount the source. If this fails, display the error and abort.
    [self.source mount];
    if (self.source.mountDissenter)
    {
        [self displayDissenter:self.source.mountDissenter
            format:@"Unable to open “%@.”", self.source.label];
        return;
    }

    // First acquire exclusive mounting rights to the destination.
    self.destination.exclusiveAccess = YES;
    // If this fails, display the error, then abort.
    if (self.destination.mountDissenter)
    {
        [self displayDissenter:self.destination.mountDissenter
            format:@"Unable to acquire access to “%@.”", self.destination.label];
        return;
    }

    // Create the task for running asr.
    self.utility = [[Utility alloc] init];
    self.utility.launchPath = @"/usr/sbin/asr";
    self.utility.arguments = @[
        @"--source", self.source.baseSystemPath,
        @"--target", [@"/dev" stringByAppendingPathComponent:self.destination.BSDName],
        @"--erase", @"--noprompt", @"--puppetstrings"
    ];

    __weak typeof(self) _self = self;

    // Set up the handler to run for each line of asr's output.
    self.utility.outputHandler = ^(NSString *outputLine)
    {
        NSArray *outputParts = [outputLine componentsSeparatedByString:@"\t"];
        if (outputParts.count < 2)
            return;

        NSString *outputKey = outputParts[0], *outputValue = outputParts[1];

        // If this line contains the percent completed, update the progress bar
        // with the value.
        if ([outputKey hasPrefix:@"P"])
            dispatch_async(dispatch_get_main_queue(),
                ^{ _self.progressIndicator.doubleValue = outputValue.intValue; });

        // If the line contains a progress milestone, update our progress status
        // details accordingly.
        else if ([outputValue isEqualToString:@"verify"])
            dispatch_async(dispatch_get_main_queue(),
                ^{ _self.progressLabel.stringValue = @"Verifying Base System"; });
    };

    // Set up the handler to run when asr terminates.
    self.utility.terminationHandler = ^(Utility *utility)
    {
        _self.utility = nil;

        // If asr exited with non-zero status, report the error and abort.
        if (utility.terminationStatus) {
            [_self displayDissenter:NULL format:@"An error occurred creating the recovery system"];
            return;
        }

        // Rename the newly restored destination with the source's label.
        DADiskRename(
            DADiskCreateFromBSDName(NULL, DASession, _self.destination.BSDName.UTF8String),
            (__bridge CFStringRef)_self.source.label,
            kDADiskRenameOptionDefault,
            // We aren't dependant on the renaming, so we don't need a callback.
            NULL,
            NULL
        );

        // Use asr to change the partition's type to Apple_Boot.
        [[Utility launchedUtilityWithLaunchPath:@"/usr/sbin/asr" arguments:@[
            @"adjust",
            @"--target", [@"/dev" stringByAppendingPathComponent:_self.destination.BSDName],
            @"--settype", @"Apple_Boot"
        ]] waitUntilExit];

        // If we are creating an installer, move on to copying the packages.
        if (_self.source.installESDPath)
            [_self copyPackages];

        // Otherwise, we are done. present the success and allow continuing to
        // the next stage.
        else {
            _self.progressLabel.stringValue = @"Recovery system created successfully";
            [_self finish];
        }
    };

    [self.utility launch];
}

- (void)copyPackages
{
    // Attempt to mount the destination volume.
    [self.destination mount];
    // Display the error and abort if unsuccessful.
    if (self.destination.mountDissenter)
    {
        [self displayDissenter:self.destination.mountDissenter
            format:@"An error occurred opening the new base system."];
        return;
    }

    // Get the path for the Dackages directory in the destination.
    NSString *packages = [self.destination.mountpoint
        stringByAppendingString:@"/System/Installation/Packages"];

    // Remove the symlink which occupies the path currently.
    [filer removeItemAtPath:packages error:nil];


    // Get the size of the source's BaseSystem.dmg file.
    NSDictionary *baseSystemAttributes =
        [filer attributesOfItemAtPath:self.source.baseSystemPath error:nil];
    NSUInteger baseSystemSize = [baseSystemAttributes[NSFileSize] unsignedIntegerValue];

    // Determine the number of bytes we need to transfer by subtracting the size
    // of the BaseSystem.dmg file fromt the size of InstallESD's partition.
    self.progressIndicator.maxValue = self.source.size - baseSystemSize;

    // Reset the progress bar's value and set a meaninful progress description.
    self.progressIndicator.doubleValue = 0;
    self.progressLabel.stringValue = @"Copying installer packages";


    self.utility = [[Utility alloc] init];
    self.utility.launchPath = @"/usr/bin/rsync";
    self.utility.arguments = @[
        // Copy recursively, maintain both symlinks and hardlinks, preserve
        // times, and preserve extended attributes.
        @"-rlHtE",
        // For each file, periodically output the number of bytes copied.
        @"--progress",
        // Don't output anything other than those progress updates.
        @"--out-format=",
        [self.source.mountpoint stringByAppendingString:@"/Packages/"], packages
    ];

    __weak typeof(self) _self = self;

    self.utility.outputHandler = ^(NSString *outputLine)
    {
        // Find the percent symbol in the line. If there is none, skip this one.
        NSUInteger toIndex = [outputLine rangeOfString:@"%"].location;
        if (toIndex == NSNotFound)
            return;

        // The first number is the number of bytes copied for the current file.
        NSUInteger bytes = [outputLine substringToIndex:toIndex-4].integerValue;

        // Update the progress bar to show the bytes copied total, between the
        // already completed files and the one currently in progress.
        _self.progressIndicator.doubleValue = _self.bytesCompleted + bytes;

        // If the percentage is 100, add the file's size to the running total.
        NSString *percentage = [outputLine substringWithRange:NSMakeRange(toIndex-3, 3)];
        if ([percentage isEqualToString:@"100"])
            _self.bytesCompleted = _self.bytesCompleted + bytes;
    };

    // Set up the handler to run when asr terminates.
    self.utility.terminationHandler = ^(Utility *utility)
    {
        _self.utility = nil;

        // Unmount our source, and detach the InstallESD if applicable.
        [_self.source unmount];
        [_self detachInstallESD];

        // If rsync exited with non-zero status, report the error then abort.
        if (utility.terminationStatus) {
            [_self displayDissenter:NULL format:@"An error occurred creating the recovery system"];
            return;
        }

        // If the copy completed, present the success and allow continuation to
        // the next stage.
        _self.progressLabel.stringValue = @"Installer created successfully";
        [_self finish];
    };

    [self.utility launch];
}

- (void)detachInstallESD
{
    // If we are not working with an installer, don't proceed.
    if (! self.source.installESDPath)
        return;

    // Get our disk object, and eject the whole disk object associated with it.
    DADiskRef disk = DADiskCreateFromBSDName(NULL, DASession, self.source.BSDName.UTF8String);
    DADiskEject(DADiskCopyWholeDisk(disk), kDADiskEjectOptionDefault, NULL, NULL);
}

- (void)finish
{
    // Hide the progress bar.
    self.progressIndicator.hidden = YES;

    // Unmount our source again if appropriate.
    [self.source unmount];
    [self.destination unmount];
    self.destination.exclusiveAccess = NO;

    // Set our completion status such that we may procede to the next stage.
    self.completed = YES;
    // Enable the Continue button.
    app.continueButton.enabled = YES;
}

@end
