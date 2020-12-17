//
//  DMMemoryCache.swift
//  YYCacheTransToSwift
//
//  Created by liumenghua on 2020/11/16.
//

import Foundation
import UIKit

class YYLinkedMapNode<Key, Value> where Key : Hashable {
    var prev: YYLinkedMapNode?
    var next: YYLinkedMapNode?
    var key: Key?
    var value: Value?
    var cost = 0
    var time: TimeInterval = 0.0
}

extension YYLinkedMapNode: Equatable {
    static func == (lhs: YYLinkedMapNode<Key, Value>, rhs: YYLinkedMapNode<Key, Value>) -> Bool {
        lhs.key == rhs.key
    }
    
    static func == <Value: Equatable>(lhs: YYLinkedMapNode<Key, Value>, rhs: YYLinkedMapNode<Key, Value>) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value
    }
}

class YYLinkedMap {
    var dic = [String: YYLinkedMapNode<String, Any>]()
    var totalCost = 0
    var totalCount = 0
    var head: YYLinkedMapNode<String, Any>?
    var tail: YYLinkedMapNode<String, Any>?
    var releaseOnMainThread = false
    var releaseAsynchronously = true
    
    func insertNodeAtHead(_ node: YYLinkedMapNode<String, Any>) {
        dic[node.key!] = node
        totalCost += node.cost
        totalCount += 1
        if head != nil {
            node.next = head
            head?.prev = node
            head = node
        } else {
            head = node
            tail = node
            head = tail
        }
    }
    
    func bringNodeToHead(_ node: YYLinkedMapNode<String, Any>) {
        guard head != node else { return }
        
        if tail == node {
            tail = node.prev
            tail?.next = nil
        } else {
            node.next?.prev = node.prev
            node.prev?.next = node.next
        }
        
        node.next = head
        node.prev = nil
        head?.prev = node
        head = node
    }
    
    func removeNode(_ node: YYLinkedMapNode<String, Any>) {
        dic.removeValue(forKey: node.key!)
        totalCost = node.cost
        totalCount -= 1
        if node.next != nil {
            node.next?.prev = node.prev
        }
        if node.prev != nil {
            node.prev?.next = node.next
        }
        if head == node {
            head = node.next
        }
        if tail == node {
            tail = node.prev
        }
    }
    
    func removeTailNode() -> YYLinkedMapNode<String, Any>? {
        guard tail != nil else { return nil }
        
        let tempTail = tail
        dic.removeValue(forKey: tail!.key!)
        totalCost = tail!.cost
        totalCount -= 1
        if head == tail {
            head = nil
            tail = nil
        } else {
            tail = tail!.prev
            tail!.next = nil
        }
        return tempTail
    }
    
    func removeAll()  {
        totalCost = 0
        totalCount = 0
        head = nil
        tail = nil
        
        guard dic.count > 0 else { return }
        dic = [String: YYLinkedMapNode<String, Any>]()
        
        // TODO: 换成Dictionary后是否不需要release，还原为C
    }
}

class DMMemoryCache {    
    // MARK: Attribute
    var name: String?
    
    // read-only
    var totalCount: Int {
        get {
            pthread_mutex_lock(&lock)
            let total = lru.totalCount
            pthread_mutex_unlock(&lock)
            return total
        }
    }
    
    // read-only
    var totalCost: Int {
        get {
            pthread_mutex_lock(&lock)
            let total = lru.totalCost
            pthread_mutex_unlock(&lock)
            return total
        }
    }
    
    // MARK: Limit
    var countLimit = Int.max
    var costLimit = Int.max
    var ageLimit: TimeInterval = Double.greatestFiniteMagnitude
    var autoTrimInterval: TimeInterval = 5.0
    var shouldRemoveAllObjectsOnMemoryWarning = true
    var shouldRemoveAllObjectsWhenEnteringBackground = true
    var didReceiveMemoryWarning: ((_ cache: DMMemoryCache) -> Void)?
    var didEnterBackground: ((_ cache: DMMemoryCache) -> Void)?
    var releaseOnMainThread: Bool {
        get {
            pthread_mutex_lock(&lock)
            let flag = lru.releaseOnMainThread
            pthread_mutex_unlock(&lock)
            return flag
        }
        set {
            pthread_mutex_lock(&lock)
            lru.releaseOnMainThread = newValue
            pthread_mutex_unlock(&lock)
        }
    }
    var releaseAsynchronously: Bool {
        get {
            pthread_mutex_lock(&lock)
            let flag = lru.releaseAsynchronously
            pthread_mutex_unlock(&lock)
            return flag
        }
        set {
            pthread_mutex_lock(&lock)
            lru.releaseAsynchronously = newValue
            pthread_mutex_unlock(&lock)
        }
    }

    // MARK: Private
    private var lock = pthread_mutex_t()
    private let lru = YYLinkedMap()
    private let queue = DispatchQueue(label: "com.dm.cache.memory", attributes: .concurrent)
    
    init() {
        pthread_mutex_init(&lock, nil);
        releaseOnMainThread = false
        releaseAsynchronously = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidReceiveMemoryWarningNotification),
                                               name: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidEnterBackgroundNotification),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        
        trimRecursively()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        lru.removeAll()
        pthread_mutex_destroy(&lock);
    }
    
    // MARK: Access Methods
    func containsObjectForKey(_ key: String) -> Bool {
        pthread_mutex_lock(&lock)
        let contain = lru.dic.keys.contains(key)
        pthread_mutex_unlock(&lock)
        return contain
    }

    func objectForKey(_ key: String) -> Any? {
        pthread_mutex_lock(&lock)
        let node = lru.dic[key]
        if node != nil {
            node!.time = CACurrentMediaTime()
            lru.bringNodeToHead(node!)
        }
        pthread_mutex_unlock(&lock)
        return node != nil ? node!.value : nil
    }
    
    func setObject(object: Any, forKey key: String) {
        setObject(object: object, forKey: key, withCost: 0)
    }

    func setObject(object: Any, forKey key: String, withCost cost: Int) {
        pthread_mutex_lock(&lock)
        var node = lru.dic[key]
        let now = CACurrentMediaTime()
        if node != nil {
            lru.totalCost -= node!.cost
            lru.totalCost += cost
            node!.cost = cost
            node!.time = now
            node!.value = object
            lru.bringNodeToHead(node!)
        } else {
            node = YYLinkedMapNode()
            node!.cost = cost
            node!.time = now
            node!.key = key
            node!.value = object
            lru .insertNodeAtHead(node!)
        }
        
        if lru.totalCost > costLimit {
            queue.async {
                self.trimToCost(self.costLimit)
            }
        }
        
        if lru.totalCount > countLimit {
//            let tailNode = lru.removeTailNode()
            lru.removeTailNode()
            // Objc 中是放到后台线程中让block去释放，Swift 中目前不确定这样是否可行
        }
        pthread_mutex_unlock(&lock)
    }
    
    func removeObjectForKey(_ key: String) {
        pthread_mutex_lock(&lock)
        let node = lru.dic[key]
        if node != nil {
            lru.removeNode(node!)
            // ...
        }
        pthread_mutex_unlock(&lock)
    }
    
    func removeAllObjects() {
        pthread_mutex_lock(&lock)
        lru.removeAll()
        pthread_mutex_unlock(&lock)
    }
    
    // MARK: Trim
    func trimToCount(_ count: Int) {
        if count == 0 {
            removeAllObjects()
            return
        }
        _trimToCount(count)
    }
    
    func trimToCost(_ cost: Int) {
        _trimToCost(cost)
    }
    
    func trimToAge(_ age: TimeInterval) {
        _trimToAge(age)
    }

    private func trimRecursively() {
        // 这个递归没有递归基？
        let globalQueue = DispatchQueue.global(qos: .userInitiated)
        globalQueue.asyncAfter(deadline: .now() + autoTrimInterval) { [weak self] in
            guard let self = self else { return }
            self.trimInBackground()
            self.trimRecursively()
        }
    }
    
    private func trimInBackground() {
        queue.async {
            self._trimToCost(self.costLimit)
            self._trimToCount(self.countLimit)
            self._trimToAge(self.ageLimit)
        }
    }
    
    private func _trimToCount(_ countLimit: Int) {
        var finish = false
        pthread_mutex_lock(&lock)
        if countLimit == 0 {
            lru.removeAll()
            finish = true
        } else if lru.totalCount <= countLimit {
            finish = true
        }
        pthread_mutex_unlock(&lock)
        guard finish != true else { return }
        
        var holder = Array<YYLinkedMapNode<String, Any>>()
        if pthread_mutex_trylock(&lock) == 0 {
            if lru.totalCount > countLimit {
                let node = lru.removeTailNode()
                if node != nil {
                    holder.append(node!)
                }
            }
            pthread_mutex_unlock(&lock)
        } else {
            usleep(10 * 1000) // 10 ms
            // 为什么是等待 10ms?
        }
        
        // 这里没懂
        if holder.count > 0 {}
    }
    
    private func _trimToCost(_ costLimit: Int) {
        var finish = false
        pthread_mutex_lock(&lock)
        if costLimit == 0 {
            lru.removeAll()
            finish = true
        } else if lru.totalCost <= costLimit {
            finish = true
        }
        pthread_mutex_unlock(&lock)
        guard finish != true else { return }
        
        var holder = Array<YYLinkedMapNode<String, Any>>()
        if pthread_mutex_trylock(&lock) == 0 {
            if lru.totalCost > costLimit {
                let node = lru.removeTailNode()
                if node != nil {
                    holder.append(node!)
                }
            }
            pthread_mutex_unlock(&lock)
        } else {
            usleep(10 * 1000) // 10 ms
            // 为什么是等待 10ms?
        }
        
        // Objc 中是放到后台线程中让block去释放，Swift 中目前不确定这样是否可行
        if holder.count > 0 {}
    }
    
    private func _trimToAge(_ ageLimit: TimeInterval) {
        var finish = false
        let now = CACurrentMediaTime()
        pthread_mutex_lock(&lock)
        if ageLimit <= 0 {
            lru.removeAll()
            finish = true
        } else if (lru.tail == nil || (now - lru.tail!.time) <= ageLimit) {
            finish = true
        }
        pthread_mutex_unlock(&lock)
        guard finish != true else { return }
        
        var holder = Array<YYLinkedMapNode<String, Any>>()
        if pthread_mutex_trylock(&lock) == 0 {
            if lru.tail != nil && (now - lru.tail!.time) > ageLimit {
                let node = lru.removeTailNode()
                if node != nil {
                    holder.append(node!)
                } else {
                    finish = true
                }
                pthread_mutex_unlock(&lock)
            } else {
                usleep(10 * 1000) // 10 ms
            }
        }
        
        // 这里没懂
        if holder.count > 0 {}
    }
    
    // MARK: Notification
    @objc private func appDidReceiveMemoryWarningNotification() {
        if self.didReceiveMemoryWarning != nil {
            (self.didReceiveMemoryWarning!)(self)
        }
        if self.shouldRemoveAllObjectsOnMemoryWarning {
            removeAllObjects()
        }
    }
    
    @objc private func appDidEnterBackgroundNotification() {
        if self.didEnterBackground != nil {
            (self.didEnterBackground!)(self)
        }
        if self.shouldRemoveAllObjectsWhenEnteringBackground {
            removeAllObjects()
        }
    }
}
