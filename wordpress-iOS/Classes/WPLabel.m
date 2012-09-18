//
//  WPLabel.m
//  WordPress
//
//  Created by Josh Bassett on 15/07/09.
//  Copyright 2009 Ivan Misuno, www.cuberoom.biz
//

#import "WPLabel.h"


@implementation WPLabel

@synthesize verticalAlignment;

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        verticalAlignment = VerticalAlignmentTop;
    }

    return self;
}

- (void)dealloc {
    [super dealloc];
}

- (void)setVerticalAlignment:(VerticalAlignment)value {
	verticalAlignment = value;
	[self setNeedsDisplay];
}

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines {
	CGRect rect = [super textRectForBounds:bounds limitedToNumberOfLines:numberOfLines];
	CGRect result;

	switch (verticalAlignment)	{
		case VerticalAlignmentTop:
			result = CGRectMake(bounds.origin.x, bounds.origin.y, rect.size.width, rect.size.height);
			break;
		case VerticalAlignmentMiddle:
			result = CGRectMake(bounds.origin.x, bounds.origin.y + (bounds.size.height - rect.size.height) / 2, rect.size.width, rect.size.height);
			break;
		case VerticalAlignmentBottom:
			result = CGRectMake(bounds.origin.x, bounds.origin.y + (bounds.size.height - rect.size.height), rect.size.width, rect.size.height);
			break;
		default:
			result = bounds;
			break;
	}

	return result;
}

- (void)drawTextInRect:(CGRect)rect {
	CGRect r = [self textRectForBounds:rect limitedToNumberOfLines:self.numberOfLines];
	[super drawTextInRect:r];
}

@end
