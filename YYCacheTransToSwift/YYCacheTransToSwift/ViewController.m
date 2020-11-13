//
//  ViewController.m
//  YYCacheTransToSwift
//
//  Created by liumenghua on 2020/11/13.
//

#import "ViewController.h"
#import "YYCacheTransToSwift-Swift.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 混编测试
    Test *test = [[Test alloc] init];
    [test testLog];
}


@end
