//
//  LFLiveFeatureConfig.m
//  LFLiveKit
//
//  Created by Jan Chen on 2019/10/31.
//

#import "LFLiveFeatureConfig.h"

@implementation LFLiveFeatureConfig

@end

@implementation LFLiveExtFilterConfig

+ (instancetype)extFilterConfigWithEnableBoxes:(BOOL)enableBoxes
                                    enableGame:(BOOL)enableGame
                                 enablePainter:(BOOL)enablePainter {
    LFLiveExtFilterConfig *config = [[LFLiveExtFilterConfig alloc] initWithEnableBoxes:enableBoxes
                                                                            enableGame:enableGame
                                                                         enablePainter:enablePainter];
    
    return config;
}

- (instancetype)initWithEnableBoxes:(BOOL)enableBoxes
                         enableGame:(BOOL)enableGame
                      enablePainter:(BOOL)enablePainter {
    if (self = [super init]) {
        _enableBoxes = enableBoxes;
        _enableGame = enableGame;
        _enablePainter = enablePainter;
    }
    
    return self;
}

@end
