//
//  main.m
//  Xrecovery
//
//  Created by Sam Rothenberg on 11/6/14.
//  Copyright (c) 2014 Sam Rothenberg. All rights reserved.
//


int main(int argc, const char * argv[])
{
    // We will be using the default file manager.
    filer = NSFileManager.defaultManager;

    // Set up the temporary directory we will be working in.
    tmpdir = [NSTemporaryDirectory() stringByAppendingString:@"org.samroth.Xrecovery/"];
    [filer createDirectoryAtPath:tmpdir withIntermediateDirectories:NO attributes:nil error:nil];
    setenv("TMPDIR", tmpdir.UTF8String, 1);

    // Create a session with Disk Arbitration that performs actions on the
    // default concurrent queue.
    DASession = DASessionCreate(NULL);
    queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    DASessionSetDispatchQueue(DASession, queue);

    return NSApplicationMain(argc, argv);
}
