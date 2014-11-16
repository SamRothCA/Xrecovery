//
//  Sources.h
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/6/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//



@interface Source : Device

@property (readonly) NSString *baseSystemPath;
@property (readonly) NSString *installESDPath;

- (id)initWithAppName:(NSString *)installerName;

@end



@interface SourceSelection : NSViewController <XrecoveryStage>

@property IBOutlet NSCollectionView *collectionView;
@property IBOutlet NSArrayController *arrayController;

- (void)addSource:(Source *)device;

@end
