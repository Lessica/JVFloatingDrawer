//
//  JVFloatingDrawerViewController.m
//  JVFloatingDrawer
//
//  Created by Julian Villella on 2015-01-11.
//  Copyright (c) 2015 JVillella. All rights reserved.
//

#import "JVFloatingDrawerViewController.h"
#import "JVFloatingDrawerView.h"
#import "JVFloatingDrawerAnimation.h"

NSString *JVFloatingDrawerSideString(JVFloatingDrawerSide side) {
    const char* c_str = 0;
#define PROCESS_VAL(p) case(p): c_str = #p; break;
    switch(side) {
            PROCESS_VAL(JVFloatingDrawerSideNone);
            PROCESS_VAL(JVFloatingDrawerSideLeft);
            PROCESS_VAL(JVFloatingDrawerSideRight);
    }
#undef PROCESS_VAL
    
    return [NSString stringWithCString:c_str encoding:NSASCIIStringEncoding];
}

@interface JVFloatingDrawerViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, strong, readonly) JVFloatingDrawerView *drawerView;
@property (nonatomic, assign) JVFloatingDrawerSide currentlyOpenedSide;
@property (nonatomic, strong) UITapGestureRecognizer *toggleDrawerTapGestureRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *toggleDrawerPanGestureRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *toggleDrawerPanBackGestureRecognizer;

@end

@implementation JVFloatingDrawerViewController

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.currentlyOpenedSide = JVFloatingDrawerSideNone;
    self.dragToRevealEnabled = YES;
    self.minimumDragDistance = 80.0;
    self.dragRespondingWidth = 80.0;
}

#pragma mark - View Related

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)loadView {
    self.drawerView = [[JVFloatingDrawerView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
}

// Convenience type-wrapper around self.view. Maybe not the best idea?
- (void)setDrawerView:(JVFloatingDrawerView *)drawerView {
    self.view = drawerView;
}

- (JVFloatingDrawerView *)drawerView {
    return (JVFloatingDrawerView *)self.view;
}

#pragma mark - Interaction

- (void)openDrawerWithSide:(JVFloatingDrawerSide)drawerSide animated:(BOOL)animated completion:(void(^)(BOOL finished))completion {
    if (self.currentlyOpenedSide != drawerSide) {
        UIView *sideView   = [self.drawerView viewContainerForDrawerSide:drawerSide];
        UIView *centerView = self.drawerView.centerViewContainer;
        
        // First close opened drawer and then open new drawer
        if (self.currentlyOpenedSide != JVFloatingDrawerSideNone) {
            [self closeDrawerWithSide:self.currentlyOpenedSide animated:animated completion:^(BOOL finished) {
                [self.animator presentationWithSide:drawerSide sideView:sideView centerView:centerView animated:animated completion:completion];
            }];
        } else {
            [self.animator presentationWithSide:drawerSide sideView:sideView centerView:centerView animated:animated completion:completion];
        }
        
        [self addDrawerGestures];
        [self.drawerView willOpenFloatingDrawerViewController:self];
    }
    
    self.currentlyOpenedSide = drawerSide;
}

- (void)closeDrawerWithSide:(JVFloatingDrawerSide)drawerSide animated:(BOOL)animated completion:(void(^)(BOOL finished))completion {
    if (self.currentlyOpenedSide == drawerSide && self.currentlyOpenedSide != JVFloatingDrawerSideNone) {
        UIView *sideView   = [self.drawerView viewContainerForDrawerSide:drawerSide];
        UIView *centerView = self.drawerView.centerViewContainer;
        
        [self.animator dismissWithSide:drawerSide sideView:sideView centerView:centerView animated:animated completion:completion];
        
        self.currentlyOpenedSide = JVFloatingDrawerSideNone;
        
        [self restoreGestures];
        
        [self.drawerView willCloseFloatingDrawerViewController:self];
    }
}

- (void)moveCenterViewWithSide:(JVFloatingDrawerSide)drawerSide translation:(CGPoint)translation {
    UIView *sideView   = [self.drawerView viewContainerForDrawerSide:drawerSide];
    UIView *centerView = self.drawerView.centerViewContainer;
    [self.animator moveWithTranslation:translation sideView:sideView centerView:centerView];
}

- (void)moveBackCenterViewWithSide:(JVFloatingDrawerSide)drawerSide translation:(CGPoint)translation {
    UIView *sideView   = [self.drawerView viewContainerForDrawerSide:drawerSide];
    UIView *centerView = self.drawerView.centerViewContainer;
    [self.animator moveBackWithTranslation:translation sideView:sideView centerView:centerView];
}

- (void)toggleDrawerWithSide:(JVFloatingDrawerSide)drawerSide animated:(BOOL)animated completion:(void(^)(BOOL finished))completion {
    if (drawerSide != JVFloatingDrawerSideNone) {
        if (drawerSide == self.currentlyOpenedSide) {
            [self closeDrawerWithSide:drawerSide animated:animated completion:completion];
        } else {
            [self openDrawerWithSide:drawerSide animated:animated completion:completion];
        }
    }
}

#pragma mark - Gestures

- (void)removeOldGestures {
    if (self.toggleDrawerPanGestureRecognizer != nil) {
        UINavigationController *navc = ((UINavigationController *)_centerViewController);
        [navc.topViewController.view removeGestureRecognizer:self.toggleDrawerPanGestureRecognizer];
        self.toggleDrawerPanGestureRecognizer = nil;
    }
    if (self.toggleDrawerTapGestureRecognizer != nil) {
        [self.drawerView.centerViewContainer removeGestureRecognizer:self.toggleDrawerTapGestureRecognizer];
        self.toggleDrawerTapGestureRecognizer = nil;
    }
    if (self.toggleDrawerPanBackGestureRecognizer != nil) {
        [self.drawerView.centerViewContainer removeGestureRecognizer:self.toggleDrawerPanBackGestureRecognizer];
        self.toggleDrawerPanBackGestureRecognizer = nil;
    }
}

- (void)addDrawerGestures {
    self.centerViewController.view.userInteractionEnabled = NO;
    [self removeOldGestures];
    if (self.dragToRevealEnabled) {
        self.toggleDrawerPanBackGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                            action:@selector(actionCenterViewContainerPanned:)];
        self.toggleDrawerPanBackGestureRecognizer.delegate = self;
        [self.drawerView.centerViewContainer addGestureRecognizer:self.toggleDrawerPanBackGestureRecognizer];
    }
    self.toggleDrawerTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(actionCenterViewContainerTapped:)];
    [self.drawerView.centerViewContainer addGestureRecognizer:self.toggleDrawerTapGestureRecognizer];
}

- (void)restoreGestures {
    [self removeOldGestures];
    if (self.dragToRevealEnabled && [_centerViewController isKindOfClass:[UINavigationController class]]) {
        self.toggleDrawerPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(actionCenterViewContainerPanned:)];
        self.toggleDrawerPanGestureRecognizer.delegate = self;
        UINavigationController *navc = ((UINavigationController *)_centerViewController);
        [navc.topViewController.view addGestureRecognizer:self.toggleDrawerPanGestureRecognizer];
    }
    self.centerViewController.view.userInteractionEnabled = YES;
}

- (void)actionCenterViewContainerTapped:(UITapGestureRecognizer *)gesture {
    if (gesture == self.toggleDrawerTapGestureRecognizer) {
        [self closeDrawerWithSide:self.currentlyOpenedSide animated:YES completion:nil];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.toggleDrawerPanGestureRecognizer) {
        UIView *centerView = self.drawerView.centerViewContainer;
        CGPoint where = [gestureRecognizer locationInView:centerView];
        UINavigationController *navc = ((UINavigationController *)_centerViewController);
        UIViewController <JVFloatingDrawerPanGestureDelegate> *topViewController = ((UIViewController <JVFloatingDrawerPanGestureDelegate> *)navc.topViewController);
        if ([topViewController respondsToSelector:@selector(shouldOpenDrawerWithSide:)]) {
            if (
                (where.x < self.dragRespondingWidth &&
                 [topViewController shouldOpenDrawerWithSide:JVFloatingDrawerSideLeft]
                 ) ||
                (where.x > (centerView.bounds.size.width - self.dragRespondingWidth) &&
                 [topViewController shouldOpenDrawerWithSide:JVFloatingDrawerSideRight]
                 )
                ) {
                return YES;
            }
        }
        return NO;
    } else if (gestureRecognizer == self.toggleDrawerPanBackGestureRecognizer) {
        return YES;
    }
    return NO;
}

static BOOL canMove = NO;
- (void)actionCenterViewContainerPanned:(UIPanGestureRecognizer *)gesture {
    CGPoint trans = [gesture translationInView:self.view];
    CGFloat transX = trans.x;
    CGFloat transY = trans.y;
    CGFloat transWidth = fabs(transX);
    BOOL toLeft = (transX >= 0.0);
    if (gesture == self.toggleDrawerPanGestureRecognizer) {
        if (gesture.state == UIGestureRecognizerStateBegan) {
            canMove = (transY < 16.0);
            [self.drawerView willOpenFloatingDrawerViewController:self];
        } else if (gesture.state == UIGestureRecognizerStateChanged) {
            if (!canMove) {
                return;
            }
            if (toLeft) {
                [self moveCenterViewWithSide:JVFloatingDrawerSideLeft translation:trans];
            } else {
                [self moveCenterViewWithSide:JVFloatingDrawerSideRight translation:trans];
            }
        } else if (gesture.state == UIGestureRecognizerStateEnded) {
            if (!canMove) {
                return;
            }
            BOOL canOpen = YES;
            UIView *sideView    = [self.drawerView viewContainerForDrawerSide:self.currentlyOpenedSide];
            UIView *centerView  = self.drawerView.centerViewContainer;
            UINavigationController *navc = ((UINavigationController *)_centerViewController);
            UIViewController <JVFloatingDrawerPanGestureDelegate> *topViewController = ((UIViewController <JVFloatingDrawerPanGestureDelegate> *)navc.topViewController);
            if (toLeft) {
                if ((
                     [topViewController respondsToSelector:@selector(shouldOpenDrawerWithSide:)]
                     && ![topViewController shouldOpenDrawerWithSide:JVFloatingDrawerSideLeft]
                     )
                    || transWidth <= self.minimumDragDistance) {
                    canOpen = NO;
                }
                if (canOpen) {
                    [self openDrawerWithSide:JVFloatingDrawerSideLeft animated:YES completion:nil];
                } else {
                    [self.animator dismissWithSide:JVFloatingDrawerSideLeft sideView:sideView centerView:centerView animated:YES completion:nil];
                    [self.drawerView willCloseFloatingDrawerViewController:self];
                }
            } else {
                if ((
                     [topViewController respondsToSelector:@selector(shouldOpenDrawerWithSide:)]
                     && ![topViewController shouldOpenDrawerWithSide:JVFloatingDrawerSideRight]
                     )
                    || transWidth <= self.minimumDragDistance) {
                    canOpen = NO;
                }
                if (canOpen) {
                    [self openDrawerWithSide:JVFloatingDrawerSideRight animated:YES completion:nil];
                } else {
                    [self.animator dismissWithSide:JVFloatingDrawerSideRight sideView:sideView centerView:centerView animated:YES completion:nil];
                    [self.drawerView willCloseFloatingDrawerViewController:self];
                }
            }
        }
    } else if (gesture == self.toggleDrawerPanBackGestureRecognizer) {
        if (gesture.state == UIGestureRecognizerStateBegan) {
            canMove = (transY < 64.0);
        } else if (gesture.state == UIGestureRecognizerStateChanged) {
            if (!canMove) {
                return;
            }
            if (!toLeft && self.currentlyOpenedSide == JVFloatingDrawerSideLeft) {
                [self moveBackCenterViewWithSide:JVFloatingDrawerSideLeft translation:trans];
            } else if (toLeft && self.currentlyOpenedSide == JVFloatingDrawerSideRight) {
                [self moveBackCenterViewWithSide:JVFloatingDrawerSideRight translation:trans];
            }
        } else if (
                   gesture.state == UIGestureRecognizerStateEnded ||
                   gesture.state == UIGestureRecognizerStateCancelled ||
                   gesture.state == UIGestureRecognizerStateFailed
                   ) {
            if (!canMove) {
                return;
            }
            BOOL canClose = YES;
            UIView *sideView    = [self.drawerView viewContainerForDrawerSide:self.currentlyOpenedSide];
            UIView *centerView  = self.drawerView.centerViewContainer;
            if (toLeft && self.currentlyOpenedSide == JVFloatingDrawerSideRight) {
                if (transWidth <= self.minimumDragDistance) {
                    canClose = NO;
                }
                if (canClose) {
                    [self closeDrawerWithSide:JVFloatingDrawerSideRight animated:YES completion:nil];
                } else {
                    [self.animator presentationWithSide:JVFloatingDrawerSideRight sideView:sideView centerView:centerView animated:YES completion:nil];
                }
            } else if (!toLeft && self.currentlyOpenedSide == JVFloatingDrawerSideLeft) {
                if (transWidth <= self.minimumDragDistance) {
                    canClose = NO;
                }
                if (canClose) {
                    [self closeDrawerWithSide:JVFloatingDrawerSideLeft animated:YES completion:nil];
                } else {
                    [self.animator presentationWithSide:JVFloatingDrawerSideLeft sideView:sideView centerView:centerView animated:YES completion:nil];
                }
            }
        }
    }
}

#pragma mark - Managed View Controllers

- (void)setLeftViewController:(UIViewController *)leftViewController {
    [self replaceViewController:self.leftViewController
             withViewController:leftViewController container:self.drawerView.leftViewContainer];
    
    _leftViewController = leftViewController;
}

- (void)setRightViewController:(UIViewController *)rightViewController {
    [self replaceViewController:self.rightViewController withViewController:rightViewController
                      container:self.drawerView.rightViewContainer];
    
    _rightViewController = rightViewController;
}

- (void)setCenterViewController:(UIViewController *)centerViewController {
    [self replaceViewController:self.centerViewController withViewController:centerViewController
                      container:self.drawerView.centerViewContainer];
    
    _centerViewController = centerViewController;
    [self.drawerView willCloseFloatingDrawerViewController:self];
    [self restoreGestures];
}

- (void)replaceViewController:(UIViewController *)sourceViewController withViewController:(UIViewController *)destinationViewController container:(UIView *)container {
    
    [sourceViewController willMoveToParentViewController:nil];
    [sourceViewController.view removeFromSuperview];
    [sourceViewController removeFromParentViewController];
    
    if (destinationViewController) {
        [self addChildViewController:destinationViewController];
        [container addSubview:destinationViewController.view];
        
        UIView *destinationView = destinationViewController.view;
        destinationView.translatesAutoresizingMaskIntoConstraints = NO;
        
        NSDictionary *views = NSDictionaryOfVariableBindings(destinationView);
        [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[destinationView]|" options:0 metrics:nil views:views]];
        [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[destinationView]|" options:0 metrics:nil views:views]];
        
        [destinationViewController didMoveToParentViewController:self];
    }
}

#pragma mark - Reveal Widths

- (void)setLeftDrawerWidth:(CGFloat)leftDrawerWidth {
    self.drawerView.leftViewContainerWidth = leftDrawerWidth;
}

- (void)setRightDrawerWidth:(CGFloat)rightDrawerWidth {
    self.drawerView.rightViewContainerWidth = rightDrawerWidth;
}

- (CGFloat)leftDrawerRevealWidth {
    return self.drawerView.leftViewContainerWidth;
}

- (CGFloat)rightDrawerRevealWidth {
    return self.drawerView.rightViewContainerWidth;
}

#pragma mark - Background Image

- (void)setBackgroundImage:(UIImage *)backgroundImage {
    self.drawerView.backgroundImageView.image = backgroundImage;
}

- (UIImage *)backgroundImage {
    return self.drawerView.backgroundImageView.image;
}

#pragma mark - Helpers

- (UIViewController *)viewControllerForDrawerSide:(JVFloatingDrawerSide)drawerSide {
    UIViewController *sideViewController = nil;
    switch (drawerSide) {
        case JVFloatingDrawerSideLeft: sideViewController = self.leftViewController; break;
        case JVFloatingDrawerSideRight: sideViewController = self.rightViewController; break;
        case JVFloatingDrawerSideNone:
            sideViewController = nil; break;
    }
    return sideViewController;
}

#pragma mark - Orientation

- (BOOL)shouldAutorotate {
    return [self.centerViewController shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return [self.centerViewController supportedInterfaceOrientations];;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return [self.centerViewController preferredInterfaceOrientationForPresentation];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    if (self.currentlyOpenedSide != JVFloatingDrawerSideNone) {
        UIView *sideView   = [self.drawerView viewContainerForDrawerSide:self.currentlyOpenedSide];
        UIView *centerView = self.drawerView.centerViewContainer;
        
        [self.animator willRotateOpenDrawerWithOpenSide:self.currentlyOpenedSide sideView:sideView centerView:centerView];
    }
    
    [self.centerViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    if (self.currentlyOpenedSide != JVFloatingDrawerSideNone) {
        UIView *sideView   = [self.drawerView viewContainerForDrawerSide:self.currentlyOpenedSide];
        UIView *centerView = self.drawerView.centerViewContainer;
        
        [self.animator didRotateOpenDrawerWithOpenSide:self.currentlyOpenedSide sideView:sideView centerView:centerView];
    }
    
    [self.centerViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

#pragma mark - Status Bar

- (UIViewController *)childViewControllerForStatusBarHidden {
    return self.centerViewController;
}

- (UIViewController *)childViewControllerForStatusBarStyle {
    return self.centerViewController;
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
