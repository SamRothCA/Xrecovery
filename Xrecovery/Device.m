//
//  Device.m
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/6/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//

// For looking up disks' icons as they are provided in DA's description.
#import <IOKit/kext/KextManager.h>


void diskMountChanged(DADiskRef disk, DADissenterRef dissenter, void *context)
{
    Device *self = (__bridge Device *)context;
    // Save any dissenter that may have been provided.
    self.mountDissenter = dissenter;
    // Signal the thread which requested the unmount to proceed.
    dispatch_semaphore_signal(self.mountSemaphore);
}

DADissenterRef unmountApproval(DADiskRef disk, void *context)
{
    Device *self = (__bridge Device *)context;
    // If we are using the disk's mountpoint, prevent it from being unmounted.
    return self.mountpoint
        ? DADissenterCreate(NULL, kDAReturnBusy, CFSTR("Device busy."))
        : NULL;
}

void descriptionChanged(DADiskRef disk, CFArrayRef watch, void *context)
{
    Device *self = (__bridge Device *)context;

    CFDictionaryRef description = DADiskCopyDescription(disk);
    CFRange keyRange = CFRangeMake(0, CFArrayGetCount(watch));

    if (CFArrayContainsValue(watch, keyRange, kDADiskDescriptionVolumeNameKey))
    {
        // For our name, use the filesystem's label. Failing that, the BSD name.
        CFStringRef label;
        if (CFDictionaryGetValueIfPresent(description, kDADiskDescriptionVolumeNameKey, (const void **)&label))
            self.label = (__bridge NSString *)label;
        else
            self.label = self.BSDName;
    }

    if (CFArrayContainsValue(watch, keyRange, kDADiskDescriptionMediaSizeKey))
    {
        // Set our size property from its value in the details.
        CFNumberRef sizeNumber = CFDictionaryGetValue(description, kDADiskDescriptionMediaSizeKey);
        CFIndex size;
        CFNumberGetValue(sizeNumber, kCFNumberCFIndexType, &size);
        self.size = size;
    }
}

void diskDisappeared(DADiskRef disk, void *context) {
    Device *self = (__bridge Device *)context;
    [self remove];
}


@implementation Device

- (NSString *)BSDName { return _BSDName; }
- (void)setBSDName:(NSString *)BSDName
{
    _BSDName = BSDName;

    // Create the dictionary that matches ourselves using the BSD name.
    const void *   matchKeys[] = { kDADiskDescriptionMediaBSDNameKey };
    const void * matchValues[] = { (__bridge CFStringRef)self.BSDName };
    self.match = CFDictionaryCreate(NULL,
        matchKeys, matchValues, sizeof(matchKeys)/sizeof(*matchKeys),
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks
    );

    // Create the array of keys to watch for changes in the disk's values.
    const void *watchKeys[] = { kDADiskDescriptionVolumeNameKey, kDADiskDescriptionMediaSizeKey };
    CFArrayRef watch = CFArrayCreate(NULL,
        watchKeys, sizeof(watchKeys)/sizeof(*watchKeys),
        &kCFTypeArrayCallBacks
    );

    // Register to observe our disk's description changing, it disappearing,
    // and attempts to unmount it.
    DARegisterDiskDescriptionChangedCallback(DASession, self.match, watch, descriptionChanged, _context);
    DARegisterDiskDisappearedCallback(DASession, self.match, diskDisappeared, _context);
    DARegisterDiskUnmountApprovalCallback(DASession, self.match, unmountApproval, _context);
}

- (id)init
{
    if (! (self = super.init)) return nil;

    // Create the semaphore to use for waiting on DA's callbacks. Start it at 0
    // so that the first routine to wait on it will block until it is signalled.
    _mountSemaphore = dispatch_semaphore_create(0);

    // Bridge ourselves to a void pointer for the context of DA callbacks.
    _context = (__bridge void *)self;

    _BSDName = nil;
    self.match = NULL;
    _mountpoint = nil;
    _mountDissenter = NULL;

    return self;
}

- (id)initWithDADisk:(DADiskRef)disk
{
    if (! (self = self.init)) return nil;

    // Covert the BSD name to use for our property.
    self.BSDName = [NSString stringWithUTF8String:DADiskGetBSDName(disk)];

    // Save the DADisk and its description to our instance variables.
    CFDictionaryRef description = DADiskCopyDescription(disk);

    // Get the dictionary describing the disk's icon.
    CFDictionaryRef iconDictionary = CFDictionaryGetValue(description, kDADiskDescriptionMediaIconKey);
    // Get the bundle ID of the icon's kext, and from that the URL to the kext,
    // and from that, the bundle itself.
    CFStringRef iconBundleID = CFDictionaryGetValue(iconDictionary, kIOBundleIdentifierKey);
    CFURLRef iconBundleURL = KextManagerCreateURLForBundleIdentifier(NULL, iconBundleID);
    CFBundleRef iconBundle = CFBundleCreate(NULL, iconBundleURL);
    // Get icon's name as it is within the kext bundle, and from that, the full
    // URL for the icon file itself.
    CFStringRef iconResourceFile = CFDictionaryGetValue(iconDictionary, CFSTR(kIOBundleResourceFileKey));
    CFURLRef iconURL = CFBundleCopyResourceURL(iconBundle, iconResourceFile, NULL, NULL);
    // Finally, set our property to the icon's URL.
    self.icon = (__bridge NSURL *)iconURL;

    // Set our size property from its value in the details.
    CFNumberRef sizeNumber = CFDictionaryGetValue(description, kDADiskDescriptionMediaSizeKey);
    CFIndex size;
    CFNumberGetValue(sizeNumber, kCFNumberCFIndexType, &size);
    self.size = size;

    // For our name, use the filesystem's label. Failing that, the BSD name.
    CFStringRef label;
    if (CFDictionaryGetValueIfPresent(description, kDADiskDescriptionVolumeNameKey, (const void **)&label))
        self.label = (__bridge NSString *)label;
    else
        self.label = self.BSDName;

    return self;
}

- (void)mount
{
    // If we ourselves have mounted the disk, no need to proceed.
    if (self.mountpoint)
        return;

    // Get the current details on our disk.
    DADiskRef disk = DADiskCreateFromBSDName(NULL, DASession, self.BSDName.UTF8String);
    CFDictionaryRef description = DADiskCopyDescription(disk);

    // If the disk is currently mounted, we will use that mountpoint.
    CFURLRef mountURL = NULL;
    if (CFDictionaryGetValueIfPresent(description, kDADiskDescriptionVolumePathKey, (const void **)&mountURL))
        self.mountpoint = (__bridge NSString *)CFURLCopyFileSystemPath(mountURL, kCFURLPOSIXPathStyle);

    else {
        // Generate a mountpoint using the disk's ID in our temporary directory.
        NSString *mountpoint = [tmpdir stringByAppendingPathComponent:self.BSDName];
        // Create the directory for the mountpoint.
        [filer createDirectoryAtPath:mountpoint
            withIntermediateDirectories:NO attributes:nil error:nil];

        // Tell DA to mount the disk.
        DADiskMountWithArguments(
            disk,
            CFURLCreateWithString(NULL, (__bridge CFStringRef)mountpoint, NULL),
            // Mount this partition only, not all the partitions on the disk.
            kDADiskMountOptionDefault,
            // Receive the results of the mount on our callback.
            diskMountChanged,
            _context,
            // The disk should not be shown in the Finder or use file ownership.
            (CFStringRef[]){ CFSTR("nobrowse"), CFSTR("noowners"), NULL }
        );

        // Wait to receive the signal that the mount attempt has completed.
        dispatch_semaphore_wait(self.mountSemaphore, DISPATCH_TIME_FOREVER);

        // If there was no error mounting the disk, set the mountpoint as our
        // property.
        if (! self.mountDissenter)
            self.mountpoint = mountpoint;
    }
}

- (void)unmount
{
    // If we aren't currently mounted, no need to proceed, or error to return.
    if (! self.mountpoint)
        return;

    // Save the current mountpoint before removing it from our propert.
    NSString *mountpoint = self.mountpoint;
    self.mountpoint = nil;

    // If the mountpoint is not one we had created, leave it alone.
    if (! [mountpoint hasPrefix:tmpdir])
        return;

    // Tell DA to unmount the device, and wait for the attempt to complete.
    DADiskUnmount(
        DADiskCreateFromBSDName(NULL, DASession, self.BSDName.UTF8String),
        // Unmount only our partition, and do not force it.
        kDADiskUnmountOptionDefault,
        // Receive the results on our callback.
        diskMountChanged,
        _context
    );
    dispatch_semaphore_wait(self.mountSemaphore, DISPATCH_TIME_FOREVER);

    // Delete the folder we'd created for the mountpoint.
    [filer removeItemAtPath:mountpoint error:nil];
}

- (void)remove
{
    [self unmount];

    DAUnregisterApprovalCallback(DASession, unmountApproval, _context);

    DAUnregisterCallback(DASession, diskDisappeared, _context);
    DAUnregisterCallback(DASession, descriptionChanged, _context);
}

@end



@implementation DeviceCollectionViewItem

- (void)setSelected:(BOOL)isSelected
{
    [super setSelected:isSelected];

    [(DeviceView *)self.view setSelected:isSelected];
    self.view.needsDisplay = YES;
}

@end



@implementation DeviceView

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.selected) {
        [NSColor.alternateSelectedControlColor set];
        NSRectFill(self.bounds);
    }
}

@end
