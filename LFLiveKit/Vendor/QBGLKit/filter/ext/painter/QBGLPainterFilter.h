//
//  QBGLPainterFilter.h
//  LFLiveKit
//
//  Created by Jan Chen on 2020/6/15.
//

#import "QBGLExtFilter.h"

@class QBGLPainterRenderInfo;

NS_ASSUME_NONNULL_BEGIN

@interface QBGLPainterFilter : QBGLExtFilter

- (void)updatePathInfos:(NSArray<QBGLPainterRenderInfo *> *)infos;

@end

NS_ASSUME_NONNULL_END
