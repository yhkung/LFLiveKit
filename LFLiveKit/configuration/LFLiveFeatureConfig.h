//
//  LFLiveFeatureConfig.h
//  LFLiveKit
//
//  Created by Jan Chen on 2019/10/31.
//

#import <Foundation/Foundation.h>

@class LFLiveExtFilterConfig;

@interface LFLiveFeatureConfig : NSObject

// 用dispatch_group的方法確認camera thread全部跑完後, 才執行glFinish
@property (assign, nonatomic) BOOL shouldHandleResignActiveByWaitCameraThread;

// 在送出 video/audio header 之後，第一個送出的 video/audio frame 必須是 key frame
@property (assign, nonatomic) BOOL ensureAVKeyFrameSentFirst;

@property (strong, nonatomic) LFLiveExtFilterConfig *extFilterConfig;

@end

@interface LFLiveExtFilterConfig : NSObject

@property (assign, nonatomic) BOOL enableBoxes;
@property (assign, nonatomic) BOOL enableGame;
@property (assign, nonatomic) BOOL enablePainter;

+ (instancetype)extFilterConfigWithEnableBoxes:(BOOL)enableBoxes
                                    enableGame:(BOOL)enableGame
                                 enablePainter:(BOOL)enablePainter;

@end
