//
//  Destinations.m
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/6/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//


DADissenterRef mountApproval(DADiskRef disk, void *context)
{
    Destination *self = (__bridge Destination *)context;
    // If we should be preventing mounting of the device, do so.
    return self.exclusiveAccess
        ? DADissenterCreate(NULL, kDAReturnExclusiveAccess, NULL)
        : NULL;
}

@implementation Destination
{
    BOOL _exclusiveAccess;
}

- (id)init
{
    if (! (self = super.init)) return nil;

    _exclusiveAccess = NO;

    return self;
}

- (void)unmountOther
{
    // If we ourselves have mounted the disk, no need to proceed.
    if (self.mountpoint)
        return;
//
    // Get the current details on our disk.
    DADiskRef disk = DADiskCreateFromBSDName(NULL, DASession, self.BSDName.UTF8String);
    CFDictionaryRef description = DADiskCopyDescription(disk);

    // If the disk is already mounted elsewhere, attempt to unmount it.
    if (CFDictionaryGetCountOfKey(description, kDADiskDescriptionVolumePathKey))
    {
        DADiskUnmount(disk, kDADiskUnmountOptionDefault, diskMountChanged, _context);
        // Wait for the unmount attempt to complete.
        dispatch_semaphore_wait(self.mountSemaphore, DISPATCH_TIME_FOREVER);
    }
}

- (void)setBSDName:(NSString *)BSDName
{
    super.BSDName = BSDName;
    DARegisterDiskMountApprovalCallback(DASession, self.match, mountApproval, _context);
}

- (BOOL)exclusiveAccess { return _exclusiveAccess; }
- (void)setExclusiveAccess:(BOOL)exclusiveAccess
{
    // If we are enabling exclusive access and the disk is mounted elsewhere,
    // unmount that.
    if (exclusiveAccess)
        [self unmountOther];

    // Apply the value to our property.
    _exclusiveAccess = exclusiveAccess;
}

- (void)mount
{
    // Unmount any external mountpoint, aborting upon failure.
    [self unmountOther];
    if (self.mountDissenter)
        return;

    // Save our current exlusive access state, then ensure it is not in place
    // before we proceed to attempt mounting of the disk.
    BOOL exclusiveAccess = self.exclusiveAccess;
    _exclusiveAccess = NO;

    [super mount];

    // Restore our previous exclusive access state.
    _exclusiveAccess = exclusiveAccess;
}

- (void)remove
{
    [super remove];

    self.exclusiveAccess = NO;
    DAUnregisterApprovalCallback(DASession, mountApproval, _context);

    [destinations.arrayController removeObject:self];
}

@end



void destinationAppeared(DADiskRef disk, void *context)
{
    CFDictionaryRef description = DADiskCopyDescription(disk);

    // Get the disk's size.
    CFNumberRef sizeNumber = CFDictionaryGetValue(description, kDADiskDescriptionMediaSizeKey);
    CFIndex size;
    CFNumberGetValue(sizeNumber, kCFNumberCFIndexType, &size);
    // If the size is smaller than that of the source, disqualify it.
    if (size < systemTransfer.source.size)
        return;

    // Get the disk's mountpoint if it has one.
    CFURLRef volumeURL = NULL;
    CFStringRef volumePath = NULL;
    if (CFDictionaryGetValueIfPresent(description, kDADiskDescriptionVolumePathKey, (const void **)&volumeURL))
        volumePath = CFURLCopyPath(volumeURL);
    // If the mountpoint is that of the root filesystem, disqualify it.
    if (volumePath && CFEqual(CFSTR("/"), volumePath))
        return;

    Destination *destination = [[Destination alloc] initWithDADisk:disk];
    [destinations addDestination:destination];
}

@implementation DestinationSelection
{
    NSMutableArray *_array;
    DASessionRef _DASession;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Set up our array controller for the collection view's content.
    _array = [[NSMutableArray alloc] init];
    self.arrayController.content = _array;
}

- (void)addDestination:(Destination *)destination
{
    // If we were passed a non-nil destination, add it to our list. Use the main
    // thread so as to properly perform UI updates.
    if (destination)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.arrayController addObject:destination];
        });
}

- (void)enterStage
{
    // When entering the destination selection stage, set up the continue button
    // to be enabled only if there is an item selected from the list.
    [app.continueButton bind:NSEnabledBinding
        toObject:self.collectionView withKeyPath:@"selectionIndexes.count" options:nil];

    // Create our own session with DA and set it to perform notifications on the
    // default concurrent queue.
    _DASession = DASessionCreate(NULL);
    DASessionSetDispatchQueue(_DASession, queue);

    // Set up a dictionary for matching partitions usable as destinations, based
    // on being partitions (not drives), and being writable.
    const void *keys[] = {
        kDADiskDescriptionMediaWholeKey,
//        kDADiskDescriptionMediaWritableKey,
//        kDADiskDescriptionDeviceInternalKey
    };
    const void *values[] = {
        kCFBooleanFalse,
//        kCFBooleanTrue,
//        kCFBooleanFalse
    };
    CFDictionaryRef match = CFDictionaryCreate(NULL,
        keys, values, sizeof(keys)/sizeof(*keys),
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks
    );
    DARegisterDiskAppearedCallback(DASession, match, destinationAppeared, NULL);
}

- (void)leaveStage
{
    // Unregister our session with DA.
    DAUnregisterCallback(_DASession, destinationAppeared, NULL);
    _DASession = NULL;

    // Reset our collection.
    [self.arrayController removeObjects:_array];

    // Unbind our selection count from the continue button.
    [app.continueButton unbind:NSEnabledBinding];
}

- (void)backAction
{
    // Set our bullet in the checklist to indicate this stage's uncompletion.
    app.selectDestinationImage.image = [NSImage imageNamed:NSImageNameStatusNone];
    // If the back button is clicked, return to the source selection stage.
    app.stage = sources;
}

- (void)continueAction
{
    // When the continue button is clicked, save the selected item.
    systemTransfer.destination = self.arrayController.selectedObjects.lastObject;

    // Set our bullet in the checklist to indicate this stage's completion.
    app.selectDestinationImage.image = [NSImage imageNamed:NSImageNameStatusAvailable];

    // Progress the stage to the system transfer.
    app.stage = systemTransfer;
}

@end
