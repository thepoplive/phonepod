ARCHS = armv7
TARGET = iphone:clang:8.4:6.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = PhonePod

PhonePod_FILES = main.m AppDelegate.m PhonePodViewController.m ClickWheelView.m
PhonePod_FRAMEWORKS = UIKit CoreGraphics QuartzCore MediaPlayer AVFoundation AssetsLibrary Foundation
PhonePod_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
PhonePod_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
THEOS_PACKAGE_FORMAT = ipa
