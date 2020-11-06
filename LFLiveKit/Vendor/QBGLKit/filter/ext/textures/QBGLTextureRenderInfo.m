//
//  QBGLTextureRenderInfo.m
//  LFLiveKit
//
//  Created by Jan Chen on 2020/5/21.
//

#import "QBGLTextureRenderInfo.h"

@implementation QBGLTextureRenderInfo

#pragma mark - Class Method

+ (NSArray<QBGLTextureRenderInfo *> *)textureRenderInfosFromArray:(NSArray<NSDictionary *> *)renderInfos {
    NSMutableArray *infos = [NSMutableArray new];
    for (NSDictionary *dict in renderInfos) {
        QBGLTextureRenderInfo *obj = [[QBGLTextureRenderInfo alloc] initWithRenderInfoDict:dict];
        if (obj) {
            [infos addObject:obj];
        }
    }
    
    return [infos copy];
}

#pragma mark - Init

- (instancetype)initWithRenderInfoDict:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    if (self = [super init]) {
        _imageName = dict[@"imageName"];
        _position = CGPointMake([dict[@"x"] floatValue],
                                [dict[@"y"] floatValue]);
        _size = CGSizeMake([dict[@"width"] floatValue],
                           [dict[@"height"] floatValue]);
        _rotation = [dict[@"rotation"] floatValue];
        _xScale = [dict[@"xScale"] floatValue];
        _yScale = [dict[@"yScale"] floatValue];
        _alpha = [dict[@"alpha"] floatValue];
        _zOrder = [dict[@"zOrder"] floatValue];
    }
    
    return self;
}

- (instancetype)initWithImageName:(NSString *)imageName
                         position:(CGPoint)position
                             size:(CGSize)size
                         rotation:(CGFloat)rotation
                           xScale:(CGFloat)xScale
                           yScale:(CGFloat)yScale
                            alpha:(CGFloat)alpha
                           zOrder:(CGFloat)zOrder {
    if (self = [super init]) {
        _imageName = imageName;
        _position = position;
        _size = size;
        _rotation = rotation;
        _xScale = xScale;
        _yScale = yScale;
        _alpha = alpha;
        _zOrder = zOrder;
    }
    
    return self;
}

@end
