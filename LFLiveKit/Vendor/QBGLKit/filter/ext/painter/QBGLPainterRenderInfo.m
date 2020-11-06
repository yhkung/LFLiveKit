//
//  QBGLPainterRenderInfo.m
//  LFLiveKit
//
//  Created by Jan Chen on 2020/6/15.
//

#import "QBGLPainterRenderInfo.h"

@implementation QBGLPainterRenderInfo

+ (NSArray<QBGLPainterRenderInfo *> *)painterRenderInfosFromArray:(NSArray<NSDictionary *> *)renderInfos {
    NSMutableArray *infos = [NSMutableArray new];
    for (NSDictionary *dict in renderInfos) {
        QBGLPainterRenderInfo *obj = [[QBGLPainterRenderInfo alloc] initWithRenderInfoDict:dict];
        if (obj) {
            [infos addObject:obj];
        }
    }
    
    return [infos copy];
}
    
- (instancetype)initWithRenderInfoDict:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    if (self = [super init]) {
        BOOL shouldClear = [dict[@"clear"] boolValue];
        
        if (shouldClear) {
            _clear = shouldClear;
            return self;
        }
        
        _redraw = [dict[@"redraw"] boolValue];
        _textureName = dict[@"textureName"];
        _blend = [dict[@"blend"] boolValue];
        _start = CGPointMake([dict[@"start.x"] floatValue],
                             [dict[@"start.y"] floatValue]);
        _end = CGPointMake([dict[@"end.x"] floatValue],
                           [dict[@"end.y"] floatValue]);
        
        _size = [dict[@"size"] floatValue];
        _gap = [dict[@"gap"] floatValue];
        _opacity = [dict[@"opacity"] floatValue];
        
        NSArray *colors = dict[@"color"];
        if ([colors isKindOfClass:[NSArray class]] && colors.count == 4) {
            _r = [colors[0] floatValue];
            _g = [colors[1] floatValue];
            _b = [colors[2] floatValue];
            _a = [colors[3] floatValue];
        }
    }
    
    return self;
}

@end
