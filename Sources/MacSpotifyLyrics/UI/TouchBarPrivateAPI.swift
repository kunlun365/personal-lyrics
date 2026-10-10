import AppKit
import ObjectiveC

/// Runtime-resolved access to the two private APIs needed to place a *persistent* item in the
/// Touch Bar Control Strip — the right-hand region that stays visible regardless of which app is
/// frontmost.
///
/// Why not the public `NSTouchBar` API: TouchBarServer only ever grants the Touch Bar's *app
/// region* to the frontmost **regular** (Dock-visible) application, and this app is `LSUIElement`
/// / `.accessory`. Attaching an `NSTouchBar` to a key window here is silently ignored — measured
/// directly: with the bar attached to a key+main window of an active app, AppKit reported
/// `isVisible == true` and called `makeItemForIdentifier`, while the hardware showed nothing. The
/// system tray + Control Strip presence pair is the only mechanism available to a menu bar app.
///
/// Everything is looked up lazily by name and every entry point is failable, so a future macOS
/// that drops a symbol degrades to "no Touch Bar item" instead of crashing.
enum TouchBarPrivateAPI {

    // MARK: - +[NSTouchBarItem addSystemTrayItem:] / +[NSTouchBarItem removeSystemTrayItem:]

    // Both are *class* methods, so the capability check must use `class_getClassMethod` (an
    // instance-method lookup would always miss) and the receiver must be the class object itself.

    private static let touchBarItemClass: AnyClass? = NSClassFromString("NSTouchBarItem")
    private static let addSystemTrayItemSelector = NSSelectorFromString("addSystemTrayItem:")
    private static let removeSystemTrayItemSelector = NSSelectorFromString("removeSystemTrayItem:")

    private static func respondsToClassMethod(_ selector: Selector) -> Bool {
        guard let cls = touchBarItemClass else { return false }
        return class_getClassMethod(cls, selector) != nil
    }

    @discardableResult
    private static func invokeClassMethod(_ selector: Selector, with argument: AnyObject) -> Bool {
        guard let cls = touchBarItemClass,
              respondsToClassMethod(selector),
              let receiver = cls as AnyObject as? NSObjectProtocol else { return false }
        // These methods return void, so `perform` hands back an Unmanaged wrapping a garbage
        // pointer. It must be discarded — calling takeRetainedValue()/takeUnretainedValue() on it
        // would over-release and crash.
        _ = receiver.perform(selector, with: argument)
        return true
    }

    @discardableResult
    static func addSystemTrayItem(_ item: NSTouchBarItem) -> Bool {
        invokeClassMethod(addSystemTrayItemSelector, with: item)
    }

    @discardableResult
    static func removeSystemTrayItem(_ item: NSTouchBarItem) -> Bool {
        invokeClassMethod(removeSystemTrayItemSelector, with: item)
    }

    // MARK: - DFRElementSetControlStripPresenceForIdentifier

    // C signature (private, DFRFoundation):
    //     void DFRElementSetControlStripPresenceForIdentifier(NSString *identifier, BOOL present);
    //
    // `NSString *` and `CFStringRef` are toll-free bridged and identical at the ABI level;
    // `CFString` is used because it is unambiguously C-representable in a `@convention(c)` type.
    //
    // `BOOL` is `_Bool` on arm64 but `signed char` on x86_64. `ObjCBool` matches `BOOL` on each
    // platform by definition, so it — not Swift's `Bool` — is the correct spelling here. This is
    // benign on Apple Silicon but would break on Intel Touch Bar Macs.

    private typealias SetControlStripPresenceFn = @convention(c) (CFString, ObjCBool) -> Void

    /// `RTLD_DEFAULT` is a macro `(void *)-2`, so Swift does not import it.
    private static let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)

    private static let dfrHandle: UnsafeMutableRawPointer? = {
        // On Touch Bar hardware AppKit has already pulled DFRFoundation into the process, so try
        // global scope first and only fall back to an explicit dlopen.
        if let global = rtldDefault,
           dlsym(global, "DFRElementSetControlStripPresenceForIdentifier") != nil {
            return global
        }
        return dlopen(
            "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation",
            RTLD_LAZY
        )
    }()

    private static let setPresenceFn: SetControlStripPresenceFn? = {
        // Note: dlsym takes the symbol name *without* the leading underscore that `nm` and
        // `dyld_info` display.
        guard let handle = dfrHandle,
              let symbol = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier")
        else { return nil }
        return unsafeBitCast(symbol, to: SetControlStripPresenceFn.self)
    }()

    /// True only when *both* halves of the mechanism resolved. Callers must check before
    /// attempting installation.
    static var isControlStripAvailable: Bool {
        setPresenceFn != nil
            && respondsToClassMethod(addSystemTrayItemSelector)
            && respondsToClassMethod(removeSystemTrayItemSelector)
    }

    @discardableResult
    static func setControlStripPresence(
        _ present: Bool,
        for identifier: NSTouchBarItem.Identifier
    ) -> Bool {
        guard let fn = setPresenceFn else { return false }
        let cfIdentifier = identifier.rawValue as CFString
        withExtendedLifetime(cfIdentifier) {
            fn(cfIdentifier, ObjCBool(present))
        }
        return true
    }

    // MARK: - System modal function bar (the wide region)

    // Control Strip tray items are capped at a narrow slot. To get real width the bar has to be
    // presented into the main Touch Bar region instead, anchored to a tray item:
    //
    //   + (void)presentSystemModalTouchBar:(NSTouchBar *)bar
    //                            placement:(long long)placement
    //             systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier;
    //
    // Apple renamed this between releases (…FunctionBar… on 10.13 and earlier,
    // …TouchBar… from 10.14), so both spellings are probed and whichever exists is used.
    //
    // `placement: 0` keeps the Control Strip visible alongside the presented bar — its buttons
    // stay reachable behind the chevron. `placement: 1` would cover the strip entirely.

    private static let touchBarClass: AnyClass? = NSClassFromString("NSTouchBar")

    private static let presentSelectors = [
        NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:"),
        NSSelectorFromString("presentSystemModalFunctionBar:placement:systemTrayItemIdentifier:")
    ]
    private static let dismissSelectors = [
        NSSelectorFromString("dismissSystemModalTouchBar:"),
        NSSelectorFromString("dismissSystemModalFunctionBar:")
    ]

    private static func resolvedClassMethod(_ candidates: [Selector]) -> (Selector, Method)? {
        guard let cls = touchBarClass else { return nil }
        for selector in candidates {
            if let method = class_getClassMethod(cls, selector) {
                return (selector, method)
            }
        }
        return nil
    }

    static var isSystemModalAvailable: Bool {
        resolvedClassMethod(presentSelectors) != nil && resolvedClassMethod(dismissSelectors) != nil
    }

    /// Three arguments, so `perform` (max two) can't be used — the implementation pointer is cast
    /// to a typed C function instead. Class methods take the class object as `self`.
    private typealias PresentFn = @convention(c) (AnyObject, Selector, NSTouchBar, Int64, NSString) -> Void

    @discardableResult
    static func presentSystemModalBar(
        _ touchBar: NSTouchBar,
        placement: Int64 = 0,
        anchoredTo identifier: NSTouchBarItem.Identifier
    ) -> Bool {
        guard let cls = touchBarClass,
              let (selector, method) = resolvedClassMethod(presentSelectors) else { return false }
        let fn = unsafeBitCast(method_getImplementation(method), to: PresentFn.self)
        fn(cls, selector, touchBar, placement, identifier.rawValue as NSString)
        return true
    }

    @discardableResult
    static func dismissSystemModalBar(_ touchBar: NSTouchBar) -> Bool {
        guard let cls = touchBarClass,
              let (selector, _) = resolvedClassMethod(dismissSelectors),
              let receiver = cls as AnyObject as? NSObjectProtocol else { return false }
        _ = receiver.perform(selector, with: touchBar)
        return true
    }

    /// Suppresses the system close box on the presented bar, so it isn't dismissed by a stray tap.
    static func setSystemModalShowsCloseBox(_ shows: Bool) {
        typealias ShowsCloseBoxFn = @convention(c) (ObjCBool) -> Void
        guard let handle = dfrHandle,
              let symbol = dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost")
        else { return }
        unsafeBitCast(symbol, to: ShowsCloseBoxFn.self)(ObjCBool(shows))
    }
}
