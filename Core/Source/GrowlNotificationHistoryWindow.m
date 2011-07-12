//
//  GrowlNotificationHistoryWindow.m
//  Growl
//
//  Created by Daniel Siemer on 9/2/10.
//  Copyright 2010 The Growl Project. All rights reserved.
//

#import "GrowlNotificationHistoryWindow.h"
#import "GrowlNotificationDatabase.h"
#import "GrowlHistoryNotification.h"
#import "GrowlApplicationController.h"
#import "GrowlPathUtilities.h"
#import "GrowlNotificationCellView.h"
#import "GrowlNotificationRowView.h"

#define GROWL_ROLLUP_WINDOW_HEIGHT @"GrowlRollupWindowHeight"
#define GROWL_ROLLUP_WINDOW_WIDTH @"GrowlRollupWindowWidth"

#define GROWL_DESCRIPTION_WIDTH_PAD 42.0
#define GROWL_DESCRIPTION_HEIGHT_PAD 28.0
#define GROWL_ROW_MINIMUM_HEIGHT 50.0

@implementation GrowlNotificationHistoryWindow

@synthesize historyTable;
@synthesize arrayController;
@synthesize countLabel;
@synthesize notificationColumn;

-(id)init
{
   if((self = [super initWithWindowNibName:@"AwayHistoryWindow" owner:self]))
   {
      currentlyShown = NO;
      [[self window] setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
      [(NSPanel*)[self window] setFloatingPanel:YES];
      
       NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];       
       GrowlNotificationDatabase *db = [GrowlNotificationDatabase sharedInstance];
       [nc addObserver:self 
              selector:@selector(growlDatabaseDidUpdate:) 
                  name:@"GrowlDatabaseUpdated"
                object:db];
       NSSortDescriptor *ascendingTime = [NSSortDescriptor sortDescriptorWithKey:@"Time" ascending:YES];
       [arrayController setSortDescriptors:[NSArray arrayWithObject:ascendingTime]];
      [historyTable setDoubleAction:@selector(userDoubleClickedNote:)];
   }
   return self;
}

-(void)dealloc
{
   [historyTable release]; historyTable = nil;
   [arrayController release]; historyTable = nil;
   historyController = nil;
      
   [super dealloc];
}

-(void)windowWillClose:(NSNotification *)notification
{
   [[GrowlNotificationDatabase sharedInstance] userReturnedAndClosedList];
   currentlyShown = NO;
}

-(void)showWindow:(id)sender
{
   [self updateTableView:NO];
   [super showWindow:sender];
}

-(void)updateTableView:(BOOL)willMerge
{
   if(!currentlyShown)
      return;

   NSError *error = nil;
    [historyTable noteNumberOfRowsChanged];
   [arrayController fetch:self];
   
   if (error)
       NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
   
   NSUInteger numberOfNotifications = [[arrayController arrangedObjects] count];
    
   NSString* description;
   
   if(numberOfNotifications == 1){
      description = [NSString stringWithFormat:NSLocalizedString(@"There was %d notification while you were away", nil), numberOfNotifications];
   } else {
      description = [NSString stringWithFormat:NSLocalizedString(@"There were %d notifications while you were away", nil), numberOfNotifications];
   }

    [countLabel setObjectValue:description];
}

-(void)resetArray
{   
   [[self window] center];
   
   currentlyShown = YES;
   [self showWindow:self];
}

-(IBAction)userDoubleClickedNote:(id)sender
{
   if([arrayController selectionIndex] != NSNotFound)
   {
      GrowlHistoryNotification *note = [[arrayController arrangedObjects] objectAtIndex:[arrayController selectionIndex]];
      [[GrowlApplicationController sharedInstance] growlNotificationDict:[note GrowlDictionary] didCloseViaNotificationClick:YES onLocalMachine:YES];
   }
}

- (IBAction)deleteNotifications:(id)sender {
    /* Logic for what note to remove from the rollup:
     * If we clicked while on a hovered note, delete that one
     * If we clicked or pressed delete while on a selected note, delete that one
     * If there are other selected notes, and we clicked delete, or a selected one, delete those as well
     */
    NSUInteger row = [historyTable rowForView:sender];
    NSMutableIndexSet *rowsToDelete = [NSMutableIndexSet indexSet];
    if(row == NSNotFound){
        NSLog(@"no row for this button");
        return;
    }
    GrowlNotificationRowView *view = [historyTable rowViewAtRow:row makeIfNecessary:NO];
    if(view && view.mouseInside){
        [rowsToDelete addIndex:row];
    }
    else if([[historyTable selectedRowIndexes] containsIndex:row]){
        [rowsToDelete addIndexes:[historyTable selectedRowIndexes]];
    }
    NSLog(@"Rows to remove from the rollup: %@", rowsToDelete);
}

-(GrowlNotificationDatabase*)historyController
{
   if(!historyController)
      historyController = [GrowlNotificationDatabase sharedInstance];
      
   return historyController;
}

-(CGFloat)heightForDescription:(NSString*)description forWidth:(CGFloat)width
{
    CGFloat padded = width - GROWL_DESCRIPTION_WIDTH_PAD;
    NSFont *font = [NSFont boldSystemFontOfSize:0];
    NSParagraphStyle *paragraph = [NSParagraphStyle defaultParagraphStyle];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, 
                                                                          paragraph, NSParagraphStyleAttributeName, nil];
    NSRect bound = [description boundingRectWithSize:NSMakeSize(padded, 0) 
                                             options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingTruncatesLastVisibleLine 
                                          attributes:attributes];
    CGFloat result = bound.size.height + GROWL_DESCRIPTION_HEIGHT_PAD;
    return (result > GROWL_ROW_MINIMUM_HEIGHT) ? result : GROWL_ROW_MINIMUM_HEIGHT;
}


#pragma mark TableView Data source methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [[arrayController arrangedObjects] count];
}

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
   if(aTableColumn == notificationColumn){
      return [[arrayController arrangedObjects] objectAtIndex:rowIndex];
   }
	return nil;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    NSString *description = [[[arrayController arrangedObjects] objectAtIndex:row] Description];
    CGFloat width = [[self window] frame].size.width;
    return [self heightForDescription:description forWidth:width];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    // Bold the text in the selected items, and unbold non-selected items
    [historyTable enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
        NSView *cellView = [rowView viewAtColumn:0];
        if ([cellView isKindOfClass:[GrowlNotificationCellView class]] && [rowView isKindOfClass:[GrowlNotificationRowView class]]) {
            GrowlNotificationRowView *tableRowView = (GrowlNotificationRowView*)rowView;
            GrowlNotificationCellView *tableCellView = (GrowlNotificationCellView *)cellView;
            NSButton *deleteButton = tableCellView.deleteButton;
            if (tableRowView.selected || tableRowView.mouseInside) {
                [deleteButton setHidden:NO];
            } else {
                [deleteButton setHidden:YES];
            }
        }
    }];
}

#pragma mark Window delegate methods

- (void)windowDidResize:(NSNotification *)note
{
    NSIndexSet *set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[arrayController arrangedObjects] count] - 1)];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.0];
    [historyTable noteHeightOfRowsWithIndexesChanged:set];
    [NSAnimationContext endGrouping];
}

#pragma mark -
#pragma mark GrowlDatabaseUpdateDelegate methods

-(void)growlDatabaseDidUpdate:(NSNotification*)notification
{
   [self updateTableView:NO];
}

@end