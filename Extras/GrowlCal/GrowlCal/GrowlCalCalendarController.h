//
//  GrowlCalCalendarController.h
//  GrowlCal
//
//  Created by Daniel Siemer on 12/20/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GrowlCalCalendarController : NSObject

@property (strong) NSMutableArray *calendars;
@property (strong) NSMutableDictionary *upcomingEvents;
@property (strong) NSMutableDictionary *upcomingEventsFired;
@property (strong) NSMutableDictionary *currentEvents;
@property (strong) NSMutableDictionary *currentEventsFired;
@property (strong) NSMutableDictionary *upcomingTasks;
@property (strong) NSMutableDictionary *upcomingTasksFired;

@property (strong) NSTimer *notifyTimer;

- (void)timerFire:(NSTimer*)timer;
- (void)loadCalendars;
- (void)saveCalendars;
- (void)loadEvents;
- (void)loadTasks;

@end