//
//  AppDelegate.m
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/6/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//


@implementation AppDelegate
{
    id<XrecoveryStage> _stage;
}

- (id<XrecoveryStage>)stage {
    return _stage;
}

- (void)setStage:(id<XrecoveryStage>)stage
{
    // Perform the current stage's exit routine.
    [_stage leaveStage];

    // Get the frame for the current stage view.
    NSRect stageViewFrame = self.stageView.frame;
    // Replace the current stage view with the new stage's view.
    [self.stageView.superview replaceSubview:self.stageView with:stage.view];
    // Set the frame of the new stage's view as was determined.
    stage.view.frame = stageViewFrame;

    // Update the stage and stage view pointers to the new ones.
    self.stageView = stage.view;
    _stage = stage;

    // Perform the new stage's entry routine.
    [_stage enterStage];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    app = self;
    sources = [[SourceSelection alloc] initWithNibName:@"Sources" bundle:nil];
    destinations = [[DestinationSelection alloc] initWithNibName:@"Destinations" bundle:nil];
    systemTransfer = [[SystemTransfer alloc] initWithNibName:@"SystemTransfer" bundle:nil];

    // Begin with our own stage.
    self.stage = self;
}


- (void)enterStage
{
    // For this initial stage, disable the back button, and enable the continue
    // button.
    app.backButton.enabled = NO;
    app.continueButton.enabled = YES;
}

- (void)leaveStage {
}

- (void)backAction {
}

- (void)continueAction {
    // When the continue button is clicked, proceed to source selection.
    self.stage = sources;
}


- (IBAction)backButtonClicked:(id)sender {
    // When the continue button is clicked, pass it on to the current stage.
    [self.stage backAction];
}

- (IBAction)continueButtonClicked:(id)sender {
    // When the continue button is clicked, pass it on to the current stage.
    [self.stage continueAction];
}

@end
