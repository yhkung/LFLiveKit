//
//  QBGLExtFilterFactory.m
//  LFLiveKit
//
//  Created by Jan Chen on 2020/5/22.
//

#import "QBGLExtFilterFactory.h"
#import "QBGLExtFilter.h"
#import "QBGLTexturesFilter.h"
#import "QBGLPainterFilter.h"

@implementation QBGLExtFilterFactory

+ (__kindof QBGLExtFilter *)filterWithType:(QBGLExtFilterType)type {
    __kindof QBGLExtFilter *filter = nil;
    switch (type) {
        case QBGLExtFilterTypeBoxes:
        case QBGLExtFilterTypeGame: {
            filter = [QBGLTexturesFilter instanceWithFilterType:type];
        } break;
        case QBGLExtFilterTypePainter: {
            filter = [QBGLPainterFilter instanceWithFilterType:type];
        } break;

        default: break;
    }
    
    return filter;
}

@end
