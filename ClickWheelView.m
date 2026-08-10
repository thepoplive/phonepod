#import "ClickWheelView.h"

@interface ClickWheelView ()
@property (nonatomic, assign) CGFloat lastAngle;
@property (nonatomic, assign) CGFloat totalAngularMovement;
@property (nonatomic, assign) BOOL touchStartedInCenter;
@property (nonatomic, assign) BOOL centerPressed;
@end

@implementation ClickWheelView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
	}
	return self;
}

- (void)setIsPlaying:(BOOL)isPlaying {
	_isPlaying = isPlaying;
	[self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
	CGFloat outerRadius = MIN(rect.size.width, rect.size.height) / 2.0;
	CGFloat centerRadius = outerRadius * 0.38;

	CGFloat locations[] = {0.0, 1.0};
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

	CGFloat colorsOuter[] = {
		0.85, 0.85, 0.87, 1.0,
		0.62, 0.62, 0.65, 1.0
	};
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, colorsOuter, locations, 2);
	CGContextSaveGState(ctx);
	CGContextAddArc(ctx, center.x, center.y, outerRadius, 0, 2 * M_PI, 0);
	CGContextClip(ctx);
	CGContextDrawRadialGradient(ctx, gradient, center, 0, center, outerRadius,
		kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	CGContextRestoreGState(ctx);
	CGGradientRelease(gradient);

	CGFloat colorsCenterNormal[] = {
		0.97, 0.97, 0.98, 1.0,
		0.80, 0.80, 0.83, 1.0
	};
	CGFloat colorsCenterPressed[] = {
		0.72, 0.72, 0.75, 1.0,
		0.60, 0.60, 0.63, 1.0
	};
	CGGradientRef centerGradient = CGGradientCreateWithColorComponents(
		colorSpace, self.centerPressed ? colorsCenterPressed : colorsCenterNormal, locations, 2);
	CGContextSaveGState(ctx);
	CGContextAddArc(ctx, center.x, center.y, centerRadius, 0, 2 * M_PI, 0);
	CGContextClip(ctx);
	CGContextDrawRadialGradient(ctx, centerGradient, center, 0, center, centerRadius,
		kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	CGContextRestoreGState(ctx);
	CGGradientRelease(centerGradient);
	CGColorSpaceRelease(colorSpace);

	CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.5 alpha:1.0].CGColor);
	CGContextSetLineWidth(ctx, 1.0);
	CGContextAddArc(ctx, center.x, center.y, centerRadius, 0, 2 * M_PI, 0);
	CGContextStrokePath(ctx);

	CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.6].CGColor);
	CGContextSetLineWidth(ctx, 0.75);
	CGContextAddArc(ctx, center.x, center.y, centerRadius - 1.5, 0, 2 * M_PI, 0);
	CGContextStrokePath(ctx);

	UIColor *glyphColor = [UIColor colorWithWhite:0.28 alpha:1.0];
	UIFont *menuFont = [UIFont fontWithName:@"Helvetica-Bold" size:outerRadius * 0.15];
	NSDictionary *menuAttrs = @{
		NSFontAttributeName: menuFont,
		NSForegroundColorAttributeName: glyphColor
	};
	[self drawLabel:@"MENU" attrs:menuAttrs center:CGPointMake(center.x, center.y - outerRadius * 0.72)];

	CGFloat iconSize = outerRadius * 0.16;
	[self drawSkipIconAtCenter:CGPointMake(center.x + outerRadius * 0.72, center.y) size:iconSize forward:YES color:glyphColor];
	[self drawSkipIconAtCenter:CGPointMake(center.x - outerRadius * 0.72, center.y) size:iconSize forward:NO color:glyphColor];
	[self drawPlayPauseIconAtCenter:CGPointMake(center.x, center.y + outerRadius * 0.72) size:iconSize color:glyphColor];
}

- (void)drawLabel:(NSString *)text attrs:(NSDictionary *)attrs center:(CGPoint)center {
	CGSize size = [text sizeWithAttributes:attrs];
	CGRect r = CGRectMake(center.x - size.width / 2, center.y - size.height / 2, size.width, size.height);
	[text drawInRect:r withAttributes:attrs];
}

- (void)drawSkipIconAtCenter:(CGPoint)c size:(CGFloat)s forward:(BOOL)forward color:(UIColor *)color {
	CGFloat dir = forward ? 1.0 : -1.0;
	CGFloat triW = s * 0.6;
	CGFloat triH = s * 1.05;
	CGFloat gap = s * 0.62;

	for (NSInteger i = 0; i < 2; i++) {
		CGFloat offsetX = dir * (gap * i - gap * 0.5);
		CGFloat baseX = c.x + offsetX;
		UIBezierPath *tri = [UIBezierPath bezierPath];
		[tri moveToPoint:CGPointMake(baseX - dir * triW / 2, c.y - triH / 2)];
		[tri addLineToPoint:CGPointMake(baseX - dir * triW / 2, c.y + triH / 2)];
		[tri addLineToPoint:CGPointMake(baseX + dir * triW / 2, c.y)];
		[tri closePath];
		[color setFill];
		[tri fill];
	}
}

- (void)drawPlayPauseIconAtCenter:(CGPoint)c size:(CGFloat)s color:(UIColor *)color {
	if (self.isPlaying) {
		CGFloat barW = s * 0.34;
		CGFloat barH = s * 1.05;
		CGFloat gap = s * 0.28;
		UIBezierPath *bar1 = [UIBezierPath bezierPathWithRoundedRect:
			CGRectMake(c.x - gap / 2 - barW, c.y - barH / 2, barW, barH) cornerRadius:barW * 0.25];
		UIBezierPath *bar2 = [UIBezierPath bezierPathWithRoundedRect:
			CGRectMake(c.x + gap / 2, c.y - barH / 2, barW, barH) cornerRadius:barW * 0.25];
		[color setFill];
		[bar1 fill];
		[bar2 fill];
	} else {
		CGFloat w = s * 0.95;
		CGFloat h = s * 1.05;
		UIBezierPath *tri = [UIBezierPath bezierPath];
		[tri moveToPoint:CGPointMake(c.x - w / 2, c.y - h / 2)];
		[tri addLineToPoint:CGPointMake(c.x - w / 2, c.y + h / 2)];
		[tri addLineToPoint:CGPointMake(c.x + w / 2, c.y)];
		[tri closePath];
		[color setFill];
		[tri fill];
	}
}

- (CGFloat)angleForPoint:(CGPoint)p {
	CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
	return atan2(p.y - center.y, p.x - center.x);
}

- (CGFloat)distanceFromCenter:(CGPoint)p {
	CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
	CGFloat dx = p.x - center.x;
	CGFloat dy = p.y - center.y;
	return sqrt(dx * dx + dy * dy);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint p = [touch locationInView:self];
	self.lastAngle = [self angleForPoint:p];
	self.totalAngularMovement = 0;

	CGFloat outerRadius = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0;
	CGFloat centerRadius = outerRadius * 0.38;
	self.touchStartedInCenter = [self distanceFromCenter:p] <= centerRadius;

	if (self.touchStartedInCenter) {
		self.centerPressed = YES;
		[self setNeedsDisplay];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if (self.touchStartedInCenter) return;

	UITouch *touch = [touches anyObject];
	CGPoint p = [touch locationInView:self];
	CGFloat angle = [self angleForPoint:p];
	CGFloat delta = angle - self.lastAngle;

	if (delta > M_PI) delta -= 2 * M_PI;
	if (delta < -M_PI) delta += 2 * M_PI;

	self.totalAngularMovement += fabs(delta);
	self.lastAngle = angle;

	if (self.totalAngularMovement > 0.08) {
		if ([self.delegate respondsToSelector:@selector(clickWheelDidScrollWithAngleDelta:)]) {
			[self.delegate clickWheelDidScrollWithAngleDelta:delta];
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint p = [touch locationInView:self];

	BOOL wasDrag = self.totalAngularMovement > 0.15;

	if (self.centerPressed) {
		self.centerPressed = NO;
		[self setNeedsDisplay];
	}

	if (wasDrag) return;

	if (self.touchStartedInCenter) {
		[self firePress:ClickWheelButtonCenter];
		return;
	}

	CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
	CGFloat dx = p.x - center.x;
	CGFloat dy = p.y - center.y;

	if (fabs(dy) >= fabs(dx)) {
		[self firePress:(dy < 0) ? ClickWheelButtonMenu : ClickWheelButtonPlayPause];
	} else {
		[self firePress:(dx > 0) ? ClickWheelButtonNext : ClickWheelButtonPrev];
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	self.centerPressed = NO;
	[self setNeedsDisplay];
}

- (void)firePress:(ClickWheelButton)button {
	if ([self.delegate respondsToSelector:@selector(clickWheelDidPressButton:)]) {
		[self.delegate clickWheelDidPressButton:button];
	}
}

@end
