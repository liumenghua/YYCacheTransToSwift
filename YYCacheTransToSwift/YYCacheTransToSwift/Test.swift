//
//  Test.swift
//  YYCacheTransToSwift
//
//  Created by liumenghua on 2020/11/13.
//

import Foundation

class Test: NSObject {
    @objc public func testLog() {
        print("Objc 和 Swift 混编成功！")
        
        
    }
        
    @objc public func testCache() {
//        let cache = DMCache.init(withName: "userInfoCache-Swfit")
//        print("cache Name:" + cache.name)
        
        let memoryCache = DMMemoryCache.init()
        memoryCache.name = "userInfoCache-Swfit"
        print(memoryCache.totalCost)
    }
}

