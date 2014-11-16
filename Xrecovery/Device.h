//
//  Device.h
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/6/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//


@interface Device : NSObject
{
    NSString *_BSDName;

    // Bridge ourselves to a void pointer for the context of DA callbacks.
    void *_context;
}

@property NSString *BSDName;
@property CFDictionaryRef match;

@property NSURL *icon;
@property NSString *label;
@property NSString *details;

@property NSUInteger size;

@property NSString *mountpoint;

// A semaphore for waiting for DA's callbacks to complete.
@property dispatch_semaphore_t mountSemaphore;
// The error associated with the last mount operation, or NULL if successful.
@property DADissenterRef mountDissenter;


- (id)initWithDADisk:(DADiskRef)disk;

- (void)mount;
- (void)unmount;

- (void)remove;


@end

void diskMountChanged(DADiskRef disk, DADissenterRef dissenter, void *context);

@interface DeviceCollectionViewItem : NSCollectionViewItem
@end


@interface DeviceView : NSView

@property BOOL selected;

@end
