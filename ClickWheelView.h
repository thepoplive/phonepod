#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ClickWheelButton) {
	ClickWheelButtonMenu,
	ClickWheelButtonNext,
	ClickWheelButtonPrev,
	ClickWheelButtonPlayPause,
	ClickWheelButtonCenter
};

@protocol ClickWheelViewDelegate <NSObject>
- (void)clickWheelDidPressButton:(ClickWheelButton)button;
- (void)clickWheelDidScrollWithAngleDelta:(CGFloat)angleDelta; // радианы, + = по часовой
@end

@interface ClickWheelView : UIView
@property (nonatomic, weak) id<ClickWheelViewDelegate> delegate;
@end
