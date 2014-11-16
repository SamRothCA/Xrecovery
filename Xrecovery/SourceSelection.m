//
//  Sources.m
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/6/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//

@interface Source ()

@property (readwrite) NSString *installESDPath;

@end
@implementation Source
{
    NSBundle *_bundle;
}

- (id)init
{
    if (! (self = super.init)) return nil;
    // Initialize with no installer application bundle or InstallESD.dmg.
    _bundle = nil;
    _installESDPath = nil;
    return self;
}

- (id)initWithAppName:(NSString *)appName
{
    if (! (self = self.init)) return nil;

    // Locate our bundle in the Applications folder.
    NSString *appPath = [@"/Applications" stringByAppendingPathComponent:appName];
    _bundle = [NSBundle bundleWithPath:appPath];

    // Get the path to the InstallESD.dmg. If it does not exist, abort.
    _installESDPath = [_bundle.sharedSupportPath stringByAppendingPathComponent:@"InstallESD.dmg"];
    if (! [filer fileExistsAtPath:self.installESDPath])
        return nil;

    // Create a utility object for hdiutil to attach the image for us.
    Utility *imageInfoUtility = [Utility launchedUtilityWithLaunchPath:@"/usr/bin/hdiutil"
        arguments:@[ @"imageinfo", self.installESDPath, @"-plist" ]];

    // Wait until the task completes.
    [imageInfoUtility waitUntilExit];

    NSDictionary *imageInfo = imageInfoUtility.outputPropertyList;

    // Get the value for the total size of the image's represented disk.
    NSString *totalBytesString = imageInfo[@"Size Information"][@"Total Bytes"];

    // If there was not valid size output from the task, abort.
    if (! totalBytesString)
        return nil;

    // Translate the size from a string to an integer and set our size to it.
    self.size = totalBytesString.integerValue;


    // Set our label and our icon to those of the application bundle.
    self.label = [_bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *iconName = [_bundle objectForInfoDictionaryKey:@"CFBundleIconFile"];
    self.icon = [_bundle URLForResource:iconName withExtension:@".icns"];

    return self;
}

- (NSString *)baseSystemPath
{
    // Start with our device's mount point.
    NSString *baseSystemPath = self.mountpoint;

    // If we are using a Recovery HD partition and not an installer application,
    // the disk image will be located in the com.apple.recovery.boot directory.
    if (! _bundle)
        baseSystemPath = [baseSystemPath stringByAppendingPathComponent:@"com.apple.recovery.boot"];

    // Return the path to the disk image.
    return [baseSystemPath stringByAppendingPathComponent:@"BaseSystem.dmg"];
}

- (void)remove
{
    [super remove];
    [sources.arrayController removeObject:self];
}

@end




void sourceAppeared(DADiskRef disk, void *context)
{
    // When a device matching a Recovery HD appears, attempt to create a source
    // from it, and add it to the list if successful.
    Source *source = [[Source alloc] initWithDADisk:disk];
    [sources addSource:source];
}


@implementation SourceSelection
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

- (void)scanApplications
{
    // Enumerate through each application in our applications folder.
    NSArray *applications = [filer contentsOfDirectoryAtPath:@"/Applications" error:nil];
    for (NSString *application in applications)
    {
        // If an application's name starts with "Install OS X," attempt to get
        // an installer source from it.
        if ([application hasPrefix:@"Install OS X "])
        {
            Source *source = [[Source alloc] initWithAppName:application];
            [sources addSource:source];
        }
    }
}

- (void)enterStage
{
    // When entering the source selection stage, start by setting the continue
    // button to be enabled only if there is an item selected from the list.
    [app.continueButton bind:NSEnabledBinding
        toObject:self.collectionView withKeyPath:@"selectionIndexes.count" options:nil];

    // Enable the back button.
    app.backButton.enabled = YES;

    // Set the focus to our collection view.
    [app.window makeFirstResponder:self.collectionView];

    // Begin asynchronously scanning for installer applications.
    dispatch_async(queue, ^{ [self scanApplications]; });

    // Create our own session with DA and set it to perform notifications on the
    // default concurrent queue.
    _DASession = DASessionCreate(NULL);
    DASessionSetDispatchQueue(_DASession, queue);

    // Set up a dictionary with which to match Recovery HD's, based on being a
    // partition (not a disk), being mountable, being HFS+, and having the name
    // "Recovery HD."
    const void *keys[] = {
        kDADiskDescriptionMediaWholeKey,
        kDADiskDescriptionVolumeMountableKey,
        kDADiskDescriptionVolumeKindKey,
        kDADiskDescriptionVolumeNameKey,
    };
    const void *values[] = {
        kCFBooleanFalse,
        kCFBooleanTrue,
        CFSTR("hfs"),
        CFSTR("Recovery HD"),
    };
    CFDictionaryRef match = CFDictionaryCreate(NULL,
        keys, values, sizeof(keys)/sizeof(*keys),
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks
    );
    DARegisterDiskAppearedCallback(DASession, match, sourceAppeared, NULL);
}

- (void)leaveStage
{
    // Unregister our session with DA.
    DAUnregisterCallback(_DASession, sourceAppeared, NULL);
    _DASession = NULL;

    // Reset our collection.
    [self.arrayController removeObjects:_array];

    // Unbind our selection count from the continue button.
    [app.continueButton unbind:NSEnabledBinding];
}

- (void)backAction
{
    // Set our bullet in the checklist to indicate this stage's uncompletion.
    app.selectSourceImage.image = [NSImage imageNamed:NSImageNameStatusNone];

    // If the back button is clicked, return to the app introduction stage.
    app.stage = app;
}

- (void)continueAction
{
    // When the continue button is clicked, save the selected item.
    systemTransfer.source = self.arrayController.selectedObjects.lastObject;

    // Set our bullet in the checklist to indicate this stage's completion.
    app.selectSourceImage.image = [NSImage imageNamed:NSImageNameStatusAvailable];

    // Progress the stage to the destination selection.
    app.stage = destinations;
}

- (void)addSource:(Source *)source
{
    // If we were passed a non-nil source, add it to our list. Use the main
    // thread so as to properly perform UI updates.
    if (source)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.arrayController addObject:source];
        });
}

@end
