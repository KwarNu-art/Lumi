#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface LUMIPassthroughWindow : UIWindow
@end
@implementation LUMIPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self.rootViewController.view) return nil;
    return hit;
}
@end

static UIWindow *LUMIWindow;
static UIButton *LUMIButton;
static UIView *LUMIPanel;
static UILabel *LUMIStats;
static CADisplayLink *LUMIDisplayLink;
static NSTimer *LUMITimer;
static id gLUMIActionTarget;
static id gLUMIFrameTarget;
static CFTimeInterval LUMILastSample;
static NSUInteger LUMIFrameCount;
static double LUMIFPS;
static BOOL LUMIPanelVisible = NO;

static NSString *LUMIThermalText(void) {
    if (@available(iOS 11.0, *)) {
        switch ([NSProcessInfo processInfo].thermalState) {
            case NSProcessInfoThermalStateNominal: return @"Normal";
            case NSProcessInfoThermalStateFair: return @"Fair";
            case NSProcessInfoThermalStateSerious: return @"Serious";
            case NSProcessInfoThermalStateCritical: return @"Critical";
            default: return @"Unknown";
        }
    }
    return @"Unavailable";
}

static double LUMIProcessCPUPercent(void) {
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t count = 0;
    if (task_threads(mach_task_self(), &threads, &count) != KERN_SUCCESS || count == 0)
        return -1.0;

    double total = 0.0;
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        thread_basic_info_data_t info;
        mach_msg_type_number_t infoCount = THREAD_BASIC_INFO_COUNT;
        if (thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)&info,
                        &infoCount) == KERN_SUCCESS && !(info.flags & TH_FLAGS_IDLE)) {
            total += (double)info.cpu_usage / (double)TH_USAGE_SCALE * 100.0;
        }
        mach_port_deallocate(mach_task_self(), threads[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof(thread_t));
    return total;
}

static NSString *LUMIStatsText(void) {
    UIDevice *device = UIDevice.currentDevice;
    device.batteryMonitoringEnabled = YES;
    NSInteger battery = (NSInteger)lrint(device.batteryLevel * 100.0);
    NSString *batteryText = device.batteryLevel < 0.0
        ? @"Battery: unavailable"
        : [NSString stringWithFormat:@"Battery: %ld%%", (long)battery];
    double cpu = LUMIProcessCPUPercent();
    NSString *cpuText = cpu < 0.0
        ? @"CPU (SpringBoard): unavailable"
        : [NSString stringWithFormat:@"CPU (SpringBoard): %.1f%%", cpu];
    NSString *fpsText = LUMIFPS > 0.0
        ? [NSString stringWithFormat:@"Panel FPS estimate: %.0f", LUMIFPS]
        : @"Panel FPS estimate: measuring";
    return [NSString stringWithFormat:
            @"LUMI  •  DEVICE STATUS\n%@\nThermal state: %@\n%@\n%@\n\n"
             "CPU is SpringBoard only. FPS is a rough panel estimate.",
             batteryText, LUMIThermalText(), cpuText, fpsText];
}

static void LUMIUpdateStats(void) {
    if (LUMIStats) LUMIStats.text = LUMIStatsText();
}

@interface LUMIFrameTarget : NSObject
- (void)tick:(CADisplayLink *)link;
@end
@implementation LUMIFrameTarget
- (void)tick:(CADisplayLink *)link {
    LUMIFrameCount++;
    CFTimeInterval now = CACurrentMediaTime();
    if (LUMILastSample == 0) LUMILastSample = now;
    CFTimeInterval elapsed = now - LUMILastSample;
    if (elapsed >= 1.0) {
        LUMIFPS = (double)LUMIFrameCount / elapsed;
        LUMIFrameCount = 0;
        LUMILastSample = now;
    }
}
@end

@interface LUMIActionTarget : NSObject
- (void)togglePanel;
- (void)dragButton:(UIPanGestureRecognizer *)gesture;
@end
@implementation LUMIActionTarget
- (void)togglePanel {
    LUMIPanelVisible = !LUMIPanelVisible;
    LUMIPanel.hidden = !LUMIPanelVisible;
    if (LUMIPanelVisible) {
        LUMILastSample = 0;
        LUMIFrameCount = 0;
        LUMIDisplayLink = [CADisplayLink displayLinkWithTarget:gLUMIFrameTarget
                                                     selector:@selector(tick:)];
        [LUMIDisplayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        LUMITimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES
                                                    block:^(NSTimer *timer) { LUMIUpdateStats(); }];
        LUMIUpdateStats();
    } else {
        [LUMITimer invalidate]; LUMITimer = nil;
        [LUMIDisplayLink invalidate]; LUMIDisplayLink = nil;
    }
}
- (void)dragButton:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateChanged ||
        gesture.state == UIGestureRecognizerStateEnded) {
        CGPoint delta = [gesture translationInView:LUMIWindow];
        CGRect frame = LUMIButton.frame;
        frame.origin.x = MAX(0, MIN(LUMIWindow.bounds.size.width - frame.size.width,
                                    frame.origin.x + delta.x));
        frame.origin.y = MAX(40, MIN(LUMIWindow.bounds.size.height - frame.size.height - 40,
                                     frame.origin.y + delta.y));
        LUMIButton.frame = frame;
        [gesture setTranslation:CGPointZero inView:LUMIWindow];
    }
}
@end

static void LUMIInstall(void) {
    if (LUMIWindow || !UIApplication.sharedApplication) return;
    CGRect bounds = UIScreen.mainScreen.bounds;
    LUMIWindow = [[LUMIPassthroughWindow alloc] initWithFrame:bounds];
    LUMIWindow.windowLevel = UIWindowLevelAlert + 1;
    LUMIWindow.backgroundColor = UIColor.clearColor;
    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = UIColor.clearColor;
    LUMIWindow.rootViewController = controller;

    gLUMIActionTarget = [LUMIActionTarget new];
    gLUMIFrameTarget = [LUMIFrameTarget new];

    LUMIButton = [UIButton buttonWithType:UIButtonTypeSystem];
    LUMIButton.frame = CGRectMake(12, bounds.size.height * 0.72, 48, 48);
    LUMIButton.layer.cornerRadius = 24;
    LUMIButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.48 blue:0.95 alpha:0.94];
    [LUMIButton setTitle:@"L" forState:UIControlStateNormal];
    [LUMIButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    LUMIButton.titleLabel.font = [UIFont boldSystemFontOfSize:23];
    [LUMIButton addTarget:gLUMIActionTarget action:@selector(togglePanel)
         forControlEvents:UIControlEventTouchUpInside];
    [LUMIButton addGestureRecognizer:[[UIPanGestureRecognizer alloc]
                                      initWithTarget:gLUMIActionTarget
                                      action:@selector(dragButton:)]];

    CGFloat panelWidth = MIN(bounds.size.width - 24, 340);
    LUMIPanel = [[UIView alloc] initWithFrame:CGRectMake(12, bounds.size.height - 220,
                                                         panelWidth, 190)];
    LUMIPanel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.96];
    LUMIPanel.layer.cornerRadius = 14;
    LUMIPanel.layer.borderWidth = 1;
    LUMIPanel.layer.borderColor = [UIColor colorWithWhite:0.4 alpha:0.8].CGColor;
    LUMIPanel.hidden = YES;
    LUMIStats = [[UILabel alloc] initWithFrame:CGRectInset(LUMIPanel.bounds, 14, 12)];
    LUMIStats.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    LUMIStats.textColor = UIColor.whiteColor;
    LUMIStats.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    LUMIStats.numberOfLines = 0;
    LUMIStats.adjustsFontSizeToFitWidth = YES;
    LUMIStats.minimumScaleFactor = 0.8;
    [LUMIPanel addSubview:LUMIStats];

    [controller.view addSubview:LUMIPanel];
    [controller.view addSubview:LUMIButton];
    LUMIWindow.hidden = NO;
}

__attribute__((constructor))
static void LUMIConstructor(void) {
    @autoreleasepool {
        if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                 addObserverForName:UIApplicationDidBecomeActiveNotification
                 object:nil queue:NSOperationQueue.mainQueue
                 usingBlock:^(NSNotification *note) { LUMIInstall(); }];
                LUMIInstall();
            });
        }
    }
}
