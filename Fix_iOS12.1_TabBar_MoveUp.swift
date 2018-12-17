//
//  Fix_iOS12.1_TabBar_MoveUp.swift
//  RefuelNow
//
//  Created by Winson Zhang on 2018/12/17.
//  Copyright © 2018 LY. All rights reserved.
//

import UIKit

/// 现目前所有的iPhone系列 tabBar 高度均是 49，除去 safeArea 外
let wm_tabBarHeight = 49.0
/// MARK: -运行时注入协议
fileprivate protocol Injectable { static func inject() }
// MARK: - UIApplication 扩展
extension UIApplication {
     /// 此问题只有在 iOS 12.1 上存在，iOS 12.1以下没有，且在iOS 12.1.1 Apple 官方已经 Fix
    open override var next: UIResponder? { if #available(iOS 12.1, *) { Swizzle.startInject() } ; return super.next }
}
/// MARK: - 执行交换的 class
final class Swizzle {
    // 开始注入
    static func startInject() { DispatchQueue.once(token: "com.wm_swizzlingInject") { TabBarButtonInject.inject() }}
}
//just extension dispatchDueue
extension DispatchQueue {
    private static var oncetcTrace = [String]()
    class func once(token: String, closure: () -> Void) {
        // 原子操作，保证线程安全且在多线程安全
        objc_sync_enter(self)
        // 在函数执行完之前 退出原子操作
        defer { objc_sync_exit(self) }
        // 如果已经执行了，则不再执行此次方法与实现的交换
        if oncetcTrace.contains(token) { return }
        oncetcTrace.append(token)
        closure()
    }
}
/// MARK: - 在运行时更改 tabBarButton 的 framw
final class TabBarButtonInject: Injectable {
    // 实现协议方法
    static func inject() {
        guard  let tabBarClass = NSClassFromString("UITabBarButton") else { return }
        // 定义一个 selector
        let originalSelector: Selector = #selector(setter:UIView.frame)
        // 获取tabBar 实例方法
        guard let originalMethod = class_getInstanceMethod(tabBarClass, originalSelector) else { return }
        // 获取 方法实现的指针
        let originalImplementation = method_getImplementation(originalMethod)
        // 设置 交换实现方法(需要转换为 OC 的 block)，才能在运行时交换
        typealias OCBlockType = @convention(block) (_ view: UIView, _ rect: CGRect) -> Void
        let swizzleImpBlock: OCBlockType = {(view, frame) in
            if view.frame.isEmpty, frame.isEmpty { return }
            var newFrame = frame
            newFrame.size.height = CGFloat(wm_tabBarHeight)
            // 指定一个接收的类型，接收的是C函数指针
            typealias SwiftImplementationType = @convention(c) (_ view: UIView, _ sel: Selector, _ frame: CGRect) -> Void
            // 危险，强转类型
            let swiftImplementation = unsafeBitCast(originalImplementation, to: SwiftImplementationType.self)
            // 调用
            swiftImplementation(view, originalSelector, newFrame)
        }
        // 强转
        let newImplementation = imp_implementationWithBlock(unsafeBitCast(swizzleImpBlock, to: AnyObject.self))
        method_setImplementation(originalMethod, newImplementation)
    }
}
