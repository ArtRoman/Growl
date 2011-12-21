//
//  GrowlTunesController.h
//  growltunes
//
//  Created by Travis Tilley on 11/7/11.
//  Copyright (c) 2011 The Growl Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>

@class ITunesConductor, FormattedItemViewController;

@interface GrowlTunesController : NSObject <GrowlApplicationBridgeDelegate, NSApplicationDelegate> {
    ITunesConductor* _iTunesConductor;
    NSMenu* _statusItemMenu;
    NSMenuItem* _currentTrackMenuItem;
    FormattedItemViewController* _currentTrackController;
    NSStatusItem* _statusItem;
    NSWindowController* _formatwc;
}

@property(readonly, retain, nonatomic) IBOutlet ITunesConductor* conductor;
@property(readwrite, retain, nonatomic) IBOutlet NSMenu* statusItemMenu;
@property(readwrite, retain, nonatomic) IBOutlet NSMenuItem* currentTrackMenuItem;
@property(readwrite, retain, nonatomic) IBOutlet FormattedItemViewController* currentTrackController;

- (IBAction)configureFormatting:(id)sender;
- (IBAction)quitGrowlTunes:(id)sender;
- (IBAction)quitGrowlTunesAndITunes:(id)sender;
- (void)createStatusItem;

@end