//
// CQMFloatingController.m
// Created by cocopon on 2011/05/19.
//
// Copyright (c) 2012 cocopon <cocopon@me.com>
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "CQMFloatingController.h"
#import "CQMFloatingContentOverlayView.h"
#import "CQMFloatingFrameView.h"

#define kDefaultMaskColor  [UIColor colorWithWhite:0 alpha:0.5]
#define kDefaultFrameColor [UIColor colorWithRed:0.10f green:0.12f blue:0.16f alpha:1.00f]
#define kDefaultFrameSize  CGSizeMake(320 - 66, 460 - 66)
#define kFramePadding      5.0f
#define kRootKey           @"root"
#define kAnimationDuration 0.3f

static inline UIImage *CQMCreateBlankImage(void) {
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 0.0);
	UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return ret;
}

@interface CQMFloatingController()

@property (nonatomic, weak) CQMFloatingFrameView *frameView;
@property (nonatomic, weak) UIView *contentView;
@property (nonatomic, weak) CQMFloatingContentOverlayView *contentOverlayView;

- (void)cqm_resizeContentOverlay;

@end

@implementation CQMFloatingController

@synthesize frameView = _frameView, contentView = contentView_, contentOverlayView = _contentOverlayView, contentViewController = contentViewController_, frameSize = _frameSize, frameColor = _frameColor;

- (id)initWithContentViewController:(UIViewController *)viewController {
	if (self = [super initWithNibName:nil bundle:nil]) {
		NSParameterAssert(viewController);
		
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			UIImage *blank = CQMCreateBlankImage();
			id navigationBarAppearance = [UINavigationBar appearanceWhenContainedIn: [self class], nil];
			id toolbarAppearance = [UIToolbar appearanceWhenContainedIn: [self class], nil];
			[navigationBarAppearance setBarStyle: UIBarStyleBlack];
			[navigationBarAppearance setBackgroundImage: blank forBarMetrics: UIBarMetricsDefault];
			[navigationBarAppearance setBackgroundImage: blank forBarMetrics: UIBarMetricsLandscapePhone];
			[toolbarAppearance setBarStyle: UIBarStyleBlack];
			[toolbarAppearance setBackgroundImage: blank forToolbarPosition: UIToolbarPositionAny barMetrics: UIBarMetricsDefault];
			[toolbarAppearance setBackgroundImage: blank forToolbarPosition: UIToolbarPositionAny barMetrics: UIBarMetricsLandscapePhone];
		});
		
		_frameSize = kDefaultFrameSize;
		_frameColor = kDefaultFrameColor;
		self.view.backgroundColor = kDefaultMaskColor;
		
		CQMFloatingFrameView *frame = [[CQMFloatingFrameView alloc] initWithFrame: CGRectMake(ceil((CGRectGetWidth(self.view.frame) - _frameSize.width) / 2), ceil((CGRectGetHeight(self.view.frame) - _frameSize.height) / 2), _frameSize.width, _frameSize.height)];
		frame.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		frame.baseColor = _frameColor;
		[self.view addSubview: frame];
		self.frameView = frame;
		
		UIView *contentContainer = [[UIView alloc] initWithFrame: frame.bounds];
		contentContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		contentContainer.clipsToBounds = YES;
		contentContainer.layer.cornerRadius = 8.0f;
		contentContainer.layer.masksToBounds = 8.0f;
		[frame addSubview: contentContainer];
				
		// Content
		UIView *content = [[UIView alloc] initWithFrame: CGRectInset(frame.bounds, kFramePadding, kFramePadding)];
		content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		content.layer.cornerRadius = 5.0f;
		[contentContainer addSubview: content];
		self.contentView = content;
		
		viewController.view.frame = self.contentView.bounds;
		viewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[content addSubview: viewController.view];
		contentViewController_ = viewController;
		[self addChildViewController: viewController];
		[viewController didMoveToParentViewController: self];
		
		if ([viewController isKindOfClass: [UINavigationController class]]) {
			UINavigationController *navigationController = (id)viewController;
			[navigationController addObserver: self forKeyPath: @"toolbar.bounds" options: NSKeyValueObservingOptionNew context: NULL];
			[navigationController addObserver: self forKeyPath: @"navigationBar.bounds" options: 0 context: NULL];
			
			self.frameView.drawsBottomHighlight = (!navigationController.toolbarHidden);
			
			[self cqm_resizeContentOverlay];
		}
		
		CQMFloatingContentOverlayView *overlay = [[CQMFloatingContentOverlayView alloc] init];
		overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		overlay.baseColor = _frameColor;
		[contentContainer addSubview: overlay];
		self.contentOverlayView = overlay;
	}
	return self;
}

- (void)cqm_resizeContentOverlay {
	if (![self.contentViewController isKindOfClass: [UINavigationController class]])
		return;
	
	CGSize contentSize = self.contentView.frame.size;
	UINavigationController *navigationController = (id)self.contentViewController;
	
	// Navigation	
	CGFloat navBarHeight = navigationController.navigationBarHidden ? 0.0 : navigationController.navigationBar.frame.size.height - 1,
	toolbarHeight = navigationController.toolbarHidden ? 0.0 : navigationController.toolbar.frame.size.height;
	
	// Content overlay
	CQMFloatingContentOverlayView *contentOverlay = self.contentOverlayView;
	
	UIRectCorner corners = 0;
	if (!navigationController.navigationBarHidden)
		corners |= UIRectCornerTopLeft | UIRectCornerTopRight;
	if (!navigationController.toolbarHidden)
		corners |= UIRectCornerBottomLeft | UIRectCornerBottomRight;
	contentOverlay.filledCorners = corners;
	
	CGFloat contentFrameWidth = [[contentOverlay class] frameWidth];
	[UIView animateWithDuration: 0.0 animations:^{
		contentOverlay.frame = CGRectMake(kFramePadding - contentFrameWidth, kFramePadding - contentFrameWidth + navBarHeight, contentSize.width  + contentFrameWidth * 2, contentSize.height - navBarHeight - toolbarHeight + contentFrameWidth * 2);
	}];
}

#pragma mark -
#pragma mark Property

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([object isEqual: self.contentViewController]) {
		[self cqm_resizeContentOverlay];

		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, ([object isToolbarHidden] ? kAnimationDuration : 0) * NSEC_PER_SEC);
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
			self.frameView.drawsBottomHighlight = (![object isToolbarHidden]);
		});
		
		return;
	}
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)setFrameSize:(CGSize)frameSize {
	if (!CGSizeEqualToSize(_frameSize, frameSize)) {
		_frameSize = frameSize;
		
		CGRect frame = self.frameView.frame;
		frame.size = _frameSize;
		self.frameView.frame = frame;
	}
}

- (void)setFrameColor:(UIColor*)frameColor {
	if (![_frameColor isEqual: frameColor]) {
		_frameColor = frameColor;
		
		self.frameView.baseColor = _frameColor;
		self.contentOverlayView.baseColor = _frameColor;
		[self.frameView setNeedsDisplay];
		[self.contentOverlayView setNeedsDisplay];
	}
}

#pragma mark -

static char windowRetainCycle;

- (void)show {
	self.view.alpha = 0.0f;
	
	UIWindow *window = [[UIApplication sharedApplication] keyWindow];
	CGRect appFrame = [[UIScreen mainScreen] applicationFrame];
	[self.view setFrame:[window convertRect:appFrame fromView:nil]];
	[window addSubview:[self view]];
	
	objc_setAssociatedObject(window, &windowRetainCycle, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[UIView animateWithDuration: kAnimationDuration animations: ^{
		 self.view.alpha = 1.0f;
	}];
}

- (void)hide {
	[UIView animateWithDuration: kAnimationDuration animations: ^{
		self.view.alpha = 0.0f;
	} completion: ^(BOOL finished){
		 if (!finished)
			 return;
		 
		UIWindow *window = self.view.window;
		[self.view removeFromSuperview];
		objc_setAssociatedObject(window, &windowRetainCycle, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	 }];
}

@end
