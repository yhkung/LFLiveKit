//
//  RKPushModuleMonitor.m
//  LFLiveKit
//
//  Created by Jan Chen on 2019/8/13.
//

#import "RKPushModuleMonitor.h"
#import <UIKit/UIKit.h>

static CGFloat const RKDefaultFrameConsumptionStoppedThreshold = 5.0f;
static CGFloat const RKDefaultVideoEncoderMalfunctionThreshold = 5.0f;


@interface RKPushModuleMonitor()

@property (strong, nonatomic) NSDate *latestVideoEncodeDate;
@property (strong, nonatomic) NSDate *latestFrameConsumptionDate;
@property (assign, nonatomic) BOOL isVideoEncodeMalfunction;
@property (assign, nonatomic) BOOL isFrameConsumptionStopped;
@property (strong, nonatomic) dispatch_queue_t monitorQueue;
@end

@implementation RKPushModuleMonitor

- (dispatch_queue_t)monitorQueue {
    if (!_monitorQueue) {
        _monitorQueue = dispatch_queue_create("com.lflivekit.rkpushmodulemonitor", DISPATCH_QUEUE_SERIAL);
    }
    
    return _monitorQueue;
}

#pragma mark - Public Methods

- (void)startMonitor {
    [self keepMonitor];
}

- (void)updateVideoEncodeDate {
    self.latestVideoEncodeDate = [NSDate date];
}

- (void)updateFrameConsumptionDate {
    self.latestFrameConsumptionDate = [NSDate date];
}

#pragma mark -- Accesor

- (void)setIsFrameConsumptionStopped:(BOOL)isFrameConsumptionStopped {
    if (_isFrameConsumptionStopped != isFrameConsumptionStopped) {
        _isFrameConsumptionStopped = isFrameConsumptionStopped;
        if ([self.delegate respondsToSelector:@selector(pushModuleMonitor:isFrameConsumptionStopped:)]) {
            [self.delegate pushModuleMonitor:self isFrameConsumptionStopped:isFrameConsumptionStopped];
        }
    }
}

- (void)setIsVideoEncodeMalfunction:(BOOL)isVideoEncodeMalfunction {
    if (_isVideoEncodeMalfunction != isVideoEncodeMalfunction) {
        _isVideoEncodeMalfunction = isVideoEncodeMalfunction;
        if ([self.delegate respondsToSelector:@selector(pushModuleMonitor:isVideoEncodeMalfunction:)]) {
            [self.delegate pushModuleMonitor:self isVideoEncodeMalfunction:isVideoEncodeMalfunction];
        }
    }
}

#pragma mark - Private Methods

- (void)keepMonitor {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), self.monitorQueue, ^{
        [weakSelf check];
        [weakSelf keepMonitor];
    });
}

- (void)check {
    NSDate *now = [NSDate date];
    // check videoEncoder 是否正常執行
    if (self.latestVideoEncodeDate) {
        NSTimeInterval videoEncodeDiff = [now timeIntervalSinceDate:self.latestVideoEncodeDate];
        self.isVideoEncodeMalfunction = videoEncodeDiff > RKDefaultVideoEncoderMalfunctionThreshold;
        if (self.isVideoEncodeMalfunction) {
            NSLog(@"[SEL] VideoEcndoeMalfunction");
        }
    }
    
    // check LFStreamingBuffer 是否正常被消耗
    if (self.latestFrameConsumptionDate) {
        NSTimeInterval frameConsumptionDiff = [now timeIntervalSinceDate:self.latestFrameConsumptionDate];
        self.isFrameConsumptionStopped = frameConsumptionDiff > RKDefaultFrameConsumptionStoppedThreshold;
        if (self.isFrameConsumptionStopped) {
            NSLog(@"[SEL] FrameConsumptionStopped");
        }
    }
}


@end
