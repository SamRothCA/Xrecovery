//
//  SystemTransfer.h
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/7/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//


@interface SystemTransfer : NSViewController <XrecoveryStage>

@property (weak) IBOutlet NSTextField *progressLabel;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

@property (weak) IBOutlet NSWindow *confirmationWindow;
@property (weak) IBOutlet NSTextField *confirmationHeader;
@property (weak) IBOutlet NSTextField *confirmationDetails;
@property (weak) IBOutlet NSButton *confirmationCancel;
@property (weak) IBOutlet NSButton *confirmationProceed;

@property Source *source;
@property Destination *destination;

@end
