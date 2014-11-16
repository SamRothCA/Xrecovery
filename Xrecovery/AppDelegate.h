//
//  AppDelegate.h
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/6/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//



@interface AppDelegate : NSObject <NSApplicationDelegate,XrecoveryStage>

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSView *stageView;

@property IBOutlet NSView *view;

@property (weak) IBOutlet NSImageView *selectSourceImage;
@property (weak) IBOutlet NSImageView *selectDestinationImage;
@property (weak) IBOutlet NSImageView *transferSystemImage;
@property (weak) IBOutlet NSImageView *selectAdditionsImage;
@property (weak) IBOutlet NSImageView *installAdditionsImage;

@property (weak) IBOutlet NSButton *backButton;
@property (weak) IBOutlet NSButton *continueButton;

@property id<XrecoveryStage> stage;

@end
