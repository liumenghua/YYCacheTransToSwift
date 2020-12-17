//
//  ViewController.m
//  YYCacheTransToSwift
//
//  Created by liumenghua on 2020/11/13.
//

#import "ViewController.h"
#import "YYCacheTransToSwift-Swift.h"
#import "YYCache/YYCache.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 混编测试
    Test *test = [[Test alloc] init];
    [test testLog];
        
    [self testYYCacheObjc];
    [self testYYCacheSwift];
}

- (void)testYYCacheObjc {
    YYCache *userInfoCache = [YYCache cacheWithName:@"userInfo"];
    [userInfoCache setObject:@"Jack" forKey:@"username" withBlock:^{
        NSLog(@"Cache Successed!");
    }];
}

- (void)testYYCacheSwift {
    Test *test = [[Test alloc] init];
    [test testCache];
}



@end
