//
//  QBGLTexturesFilter.h
//  LFLiveKit
//
//  Created by Jan Chen on 2020/5/7.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <UIKit/UIKit.h>
#import "QBGLUtils.h"
#import "QBGLFilter.h"
#import "QBGLExtFilter.h"
#import "QBGLProgram.h"

NS_ASSUME_NONNULL_BEGIN
@class QBGLTextureRenderInfo;

@interface QBGLTexturesFilter : QBGLExtFilter

- (void)updateTextures:(NSArray<QBGLTextureRenderInfo *> *)infos;

@end

NS_ASSUME_NONNULL_END
