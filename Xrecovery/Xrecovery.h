//
//  Xrecovery.h
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/6/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//


//@class AppDelegate, Sources, Destinations, SystemTransfer;

NSString *tmpdir;

dispatch_queue_t queue;

DASessionRef DASession;

NSFileManager *filer;


AppDelegate *app;

SourceSelection *sources;
DestinationSelection *destinations;
SystemTransfer *systemTransfer;
