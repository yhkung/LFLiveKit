//
//  QBGLExtFilter.m
//  LFLiveKit
//
//  Created by Jan Chen on 2020/5/22.
//

#import "QBGLExtFilter.h"

@implementation QBGLExtFilter

#pragma mark - Life Cycle

+ (instancetype)instanceWithFilterType:(QBGLExtFilterType)filterType {
    return [[self alloc] initWithFilterType:filterType];
}

- (instancetype)initWithFilterType:(QBGLExtFilterType)filterType {
    if (self == [self init]) {
        _filterType = filterType;
    }
    return self;
}

- (void)prepareSetup {
    // implement by subclass
}

- (void)drawExternalContent {
    // implement by subclass
}

@end

