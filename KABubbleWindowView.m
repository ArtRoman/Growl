#import "KABubbleWindowView.h"
#import <math.h>

void KABubbleShadeInterpolate( void *info, float const *inData, float *outData ) {
	static float dark[4] = { .69412, .83147, .96078, .95 };
	static float light[4] = { .93725, .96863, .99216, .95 };
	register float a = inData[0], a_coeff = 1.0f - a;
	register int i = 0;

	for( i = 0; i < 4; i++ )
		outData[i] = a_coeff * dark[i] + a * light[i];
}

#pragma mark -

@implementation KABubbleWindowView
- (id) initWithFrame:(NSRect) frame {
	if( self = [super initWithFrame:frame] ) {
		_icon   = nil;
		_title  = nil;
		_text   = nil;
		_textHeight = 0;
		_target = nil;
		_action = NULL;
	}
	return self;
}

- (void) dealloc {
	[_icon release];
	[_title release];
	[_text release];

	_icon = nil;
	_title = nil;
	_text = nil;
	_target = nil;

	[super dealloc];
}

- (void) drawRect:(NSRect) rect {
	NSRect bounds = [self bounds];

	[[NSColor clearColor] set];
	NSRectFill( [self frame] );

	float lineWidth = 4.;
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:lineWidth];

	float radius = 9.;
	NSRect irect = NSInsetRect( bounds, radius + lineWidth, radius + lineWidth );
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( irect ), 
														 NSMinY( irect ) ) 
									 radius:radius 
								 startAngle:180. 
								   endAngle:270.];
	
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( irect ), 
														 NSMinY( irect ) ) 
									 radius:radius 
								 startAngle:270. 
								   endAngle:360.];
	
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( irect ), 
														 NSMaxY( irect ) ) 
									 radius:radius 
								 startAngle:0. 
								   endAngle:90.];
	
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( irect ), 
														 NSMaxY( irect ) ) 
									 radius:radius 
								 startAngle:90. 
								   endAngle:180.];
	
	[path closePath];

	[[NSGraphicsContext currentContext] saveGraphicsState];

	[path setClip];

	struct CGFunctionCallbacks callbacks = { 0, KABubbleShadeInterpolate, NULL };
	CGFunctionRef function = CGFunctionCreate( NULL, 1, NULL, 4, NULL, &callbacks );
	CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();

	float srcX = NSMinX( bounds ), srcY = NSMinY( bounds );
	float dstX = NSMinX( bounds ), dstY = NSMaxY( bounds );
	CGShadingRef shading = CGShadingCreateAxial( cspace, 
												 CGPointMake( srcX, srcY ), 
												 CGPointMake( dstX, dstY ), 
												 function, false, false );	

	CGContextDrawShading( [[NSGraphicsContext currentContext] graphicsPort], shading );

	CGShadingRelease( shading );
	CGColorSpaceRelease( cspace );
	CGFunctionRelease( function );

	[[NSGraphicsContext currentContext] restoreGraphicsState];

	[[NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:.5] set];
	[path stroke];

	// Top of the drawing area. The eye candy takes up 10 pixels on 
	// the top, so we've reserved some space for it.
	int heightOffset = [self frame].size.height - 10;

	[_title drawAtPoint:NSMakePoint( 55., heightOffset - 15. ) withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:13.], NSFontAttributeName, [NSColor controlTextColor], NSForegroundColorAttributeName, nil]];
	[_text drawInRect:NSMakeRect( 55., 10., 200., heightOffset - 25. )];

	NSSize iconSize = [_icon size];
	if( iconSize.width > 32. || iconSize.height > 32. ) {

		// scale the image appropriately
		float newWidth, newHeight, newX, newY;
		if( iconSize.width > iconSize.height ) {
			newWidth = 32.;
			newHeight = 32. / iconSize.width * iconSize.height;
		} else if( iconSize.width < iconSize.height ) {
			newWidth = 32. / iconSize.height * iconSize.width;
			newHeight = 32.;
		} else {
			newWidth = 32.;
			newHeight = 32.;
		}
		
		newX = floorf((32 - newWidth) / 2.);
		newY = floorf((32 - newHeight) / 2.);
		
		NSRect newBounds = { { newX, newY }, { newWidth, newHeight } };
		NSImageRep *sourceImageRep = [_icon bestRepresentationForDevice:nil];
		[_icon autorelease];
		_icon = [[NSImage alloc] initWithSize:NSMakeSize(32., 32.)];
		[_icon lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
		[sourceImageRep drawInRect:newBounds];
		[_icon unlockFocus];
	}

	[_icon compositeToPoint:NSMakePoint( 15., heightOffset - 35. ) operation:NSCompositeSourceAtop fraction:1.];

	[[self window] invalidateShadow];
}

#pragma mark -

- (void) setIcon:(NSImage *) icon {
	[_icon autorelease];
	_icon = [icon retain];
	[self setNeedsDisplay:YES];
}

- (void) setTitle:(NSString *) title {
	[_title autorelease];
	_title = [title copy];
	[self setNeedsDisplay:YES];
}

- (void) setAttributedText:(NSAttributedString *) text {
	[_text autorelease];
	_text = [text copy];
	_textHeight = 0;
	[self setNeedsDisplay:YES];
	[self sizeToFit];
}

- (void) setText:(NSString *) text {
	[_text autorelease];
	_text = [[NSAttributedString alloc] initWithString:text attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont messageFontOfSize:11.], NSFontAttributeName, [NSColor controlTextColor], NSForegroundColorAttributeName, nil]];
	_textHeight = 0;
	[self setNeedsDisplay:YES];
	[self sizeToFit];
}

- (void) sizeToFit {
    NSRect rect = [self frame];
	rect.size.height = 10 + 10 + 15 + [self descriptionHeight];
	[self setFrame:rect];
}

- (float) descriptionHeight {
	
	if (_textHeight == 0)
	{
		NSTextStorage* textStorage = [[NSTextStorage alloc] initWithAttributedString:_text];
		NSTextContainer* textContainer = [[[NSTextContainer alloc]
			initWithContainerSize:NSMakeSize ( 200., FLT_MAX )] autorelease];
		NSLayoutManager* layoutManager = [[[NSLayoutManager alloc] init] autorelease];

		[layoutManager addTextContainer:textContainer];
		[textStorage addLayoutManager:layoutManager];
		(void)[layoutManager glyphRangeForTextContainer:textContainer];
	
		_textHeight = [layoutManager usedRectForTextContainer:textContainer].size.height;
	
		// for some reason, this code is using a 13-point line height for calculations, but the font 
		// in fact renders in 14 points of space. Do some adjustments.
		int _rowCount = _textHeight / 13;
		BOOL limitPref = YES;
		READ_GROWL_PREF_BOOL(KALimitPref, @"com.growl.BubblesNotificationView", &limitPref);
		if (limitPref)
			_textHeight = MIN(_rowCount, 5) * 14;
		else
			_textHeight = _textHeight / 13 * 14;
	}
	return MAX (_textHeight, 30);
}

- (int) descriptionRowCount {
	float height = [self descriptionHeight];
	float lineHeight = [_text size].height;
	BOOL limitPref = YES;
	READ_GROWL_PREF_BOOL(KALimitPref, @"com.growl.BubblesNotificationView", &limitPref);
	if (limitPref)
		return MIN((int) (height / lineHeight), 5);
	else
		return (int) (height / lineHeight);
}

#pragma mark -

- (id) target {
	return _target;
}

- (void) setTarget:(id) object {
	_target = object;
}

#pragma mark -

- (SEL) action {
	return _action;
}

- (void) setAction:(SEL) selector {
	_action = selector;
}

#pragma mark -

 - (void) mouseUp:(NSEvent *) event {
	if( _target && _action && [_target respondsToSelector:_action] )
		[_target performSelector:_action withObject:self];
}
@end
