#import "ClickWheelView.h"

@interface ClickWheelView ()
@property (nonatomic, assign) CGFloat lastAngle;
@property (nonatomic, assign) CGFloat totalAngularMovement;
@property (nonatomic, assign) BOOL touchStartedInCenter;
@property (nonatomic, assign) CGPoint touchStartPoint;
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

- (void)drawRect:(CGRect)rect {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
	CGFloat outerRadius = MIN(rect.size.width, rect.size.height) / 2.0;
	CGFloat centerRadius = outerRadius * 0.38;

	// Внешнее серебристое кольцо (радиальный градиент имитируем слоями)
	CGFloat locations[] = {0.0, 1.0};
	CGFloat colorsOuter[] = {
		0.85, 0.85, 0.87, 1.0,
		0.62, 0.62, 0.65, 1.0
	};
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, colorsOuter, locations, 2);
	CGContextSaveGState(ctx);
	CGContextAddArc(ctx, center.x, center.y, outerRadius, 0, 2 * M_PI, 0);
	CGContextClip(ctx);
	CGContextDrawRadialGradient(ctx, gradient, center, 0, center, outerRadius,
		kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	CGContextRestoreGState(ctx);
	CGGradientRelease(gradient);

	// Центральная кнопка select
	CGFloat colorsCenter[] = {
		0.95, 0.95, 0.96, 1.0,
		0.75, 0.75, 0.78, 1.0
	};
	CGGradientRef centerGradient = CGGradientCreateWithColorComponents(colorSpace, colorsCenter, locations, 2);
	CGContextSaveGState(ctx);
	CGContextAddArc(ctx, center.x, center.y, centerRadius, 0, 2 * M_PI, 0);
	CGContextClip(ctx);
	CGContextDrawRadialGradient(ctx, centerGradient, center, 0, center, centerRadius,
		kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	CGContextRestoreGState(ctx);
	CGGradientRelease(centerGradient);
	CGColorSpaceRelease(colorSpace);

	// Подписи по краям
	UIFont *font = [UIFont fontWithName:@"Helvetica" size:outerRadius * 0.16];
	NSDictionary *attrs = @{
		NSFontAttributeName: font,
		NSForegroundColorAttributeName: [UIColor colorWithWhite:0.25 alpha:1.0]
	};

	[self drawLabel:@"MENU" attrs:attrs center:CGPointMake(center.x, center.y - outerRadius * 0.72)];
	[self drawSymbol:@"▶▶" attrs:attrs center:CGPointMake(center.x + outerRadius * 0.72, center.y)];
	[self drawSymbol:@"◀◀" attrs:attrs center:CGPointMake(center.x - outerRadius * 0.72, center.y)];
	[self drawSymbol:@"▶ ❙❙" attrs:attrs center:CGPointMake(center.x, center.y + outerRadius * 0.72)];
}

- (void)drawLabel:(NSString *)text attrs:(NSDictionary *)attrs center:(CGPoint)center {
	CGSize size = [text sizeWithAttributes:attrs];
	CGRect r = CGRectMake(center.x - size.width / 2, center.y - size.height / 2, size.width, size.height);
	[text drawInRect:r withAttributes:attrs];
}

- (void)drawSymbol:(NSString *)text attrs:(NSDictionary *)attrs center:(CGPoint)center {
	[self drawLabel:text attrs:attrs center:center];
}

#pragma mark - Touch handling

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
	self.touchStartPoint = p;
	self.lastAngle = [self angleForPoint:p];
	self.totalAngularMovement = 0;

	CGFloat outerRadius = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0;
	CGFloat centerRadius = outerRadius * 0.38;
	self.touchStartedInCenter = [self distanceFromCenter:p] <= centerRadius;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if (self.touchStartedInCenter) return;

	UITouch *touch = [touches anyObject];
	CGPoint p = [touch locationInView:self];
	CGFloat angle = [self angleForPoint:p];
	CGFloat delta = angle - self.lastAngle;

	// нормализация перехода через ±π
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
	if (wasDrag) return; // это было прокручивание колеса, не нажатие кнопки

	if (self.touchStartedInCenter) {
		[self firePress:ClickWheelButtonCenter];
		return;
	}

	CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
	CGFloat dx = p.x - center.x;
	CGFloat dy = p.y - center.y;

	// Определяем зону по доминирующей оси
	if (fabs(dy) >= fabs(dx)) {
		[self firePress:(dy < 0) ? ClickWheelButtonMenu : ClickWheelButtonPlayPause];
	} else {
		[self firePress:(dx > 0) ? ClickWheelButtonNext : ClickWheelButtonPrev];
	}
}

- (void)firePress:(ClickWheelButton)button {
	if ([self.delegate respondsToSelector:@selector(clickWheelDidPressButton:)]) {
		[self.delegate clickWheelDidPressButton:button];
	}
}

@end
