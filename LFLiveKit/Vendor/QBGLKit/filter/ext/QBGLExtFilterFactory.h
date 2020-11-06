//
//  QBGLExtFilterFactory.h
//  LFLiveKit
//
//  Created by Jan Chen on 2020/5/22.
//

#import <Foundation/Foundation.h>
#import "QBGLExtFilterType.h"

@class QBGLExtFilter;

NS_ASSUME_NONNULL_BEGIN

@interface QBGLExtFilterFactory : NSObject

+ (__kindof QBGLExtFilter *)filterWithType:(QBGLExtFilterType)type;

@end

NS_ASSUME_NONNULL_END
