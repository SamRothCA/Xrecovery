//
//  Destinations.h
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/6/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//


@interface Destination : Device

@property BOOL exclusiveAccess;

@end


@interface DestinationSelection : NSViewController <XrecoveryStage>

@property (weak) IBOutlet NSCollectionView *collectionView;
@property (weak) IBOutlet NSArrayController *arrayController;

- (void)addDestination:(Destination *)device;

@end

