import AppKit
import UserNotifications

// Match Clipglass's native AppKit glass, 26pt corners, light veil and typography.
@MainActor final class GlassVeil: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.18).setFill()
        bounds.fill()
    }
}

@MainActor final class TimerWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private var window: TimerWindow!
    private let entry = NSTextField()
    private let title = NSTextField(labelWithString: "Timeglass")
    private let clock = NSTextField(labelWithString: "10:00")
    private let hint = NSTextField(labelWithString: "Enter to start · Esc to hide")
    private let settings = NSButton(title: "Notification settings…", target: nil, action: nil)
    private let center = UNUserNotificationCenter.current()
    private let store = TimerStore()
    private var active: ActiveTimer?
    private var pendingID: String?
    private var generation = UUID()
    private var pulse: Timer?
    private var keys: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        center.delegate = self
        makeWindow()
        makeMenu()
        pulse = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(pulse!, forMode: .common)
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if modifiers.isEmpty && (event.keyCode == 36 || event.keyCode == 76) {
                if !event.isARepeat { self.toggleTimer() }
                return nil
            }
            if modifiers.isEmpty && event.keyCode == 53 { self.window.orderOut(nil); return nil }
            return event
        }
        showWindow()
        restore()
    }

    private func makeWindow() {
        let frame = NSRect(x: 0, y: 0, width: 480, height: 198)
        window = TimerWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.title = "Timeglass"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        let glass = NSGlassEffectView(frame: frame)
        glass.style = .regular
        glass.cornerRadius = 26
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 26
        glass.layer?.masksToBounds = true
        let content = GlassVeil(frame: frame)
        glass.contentView = content
        window.contentView = glass
        title.frame = NSRect(x: 26, y: 151, width: 428, height: 22)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.textColor = .secondaryLabelColor
        content.addSubview(title)
        entry.frame = NSRect(x: 24, y: 75, width: 432, height: 57)
        entry.font = .systemFont(ofSize: 42, weight: .regular)
        entry.placeholderString = "10m"
        entry.isBordered = false
        entry.drawsBackground = false
        entry.focusRingType = .none
        entry.cell?.isScrollable = true
        entry.setAccessibilityLabel("Timer duration")
        content.addSubview(entry)
        clock.frame = entry.frame
        clock.font = .monospacedDigitSystemFont(ofSize: 44, weight: .regular)
        clock.isHidden = true
        clock.setAccessibilityLabel("Time remaining")
        content.addSubview(clock)
        hint.frame = NSRect(x: 26, y: 30, width: 428, height: 20)
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        content.addSubview(hint)
        settings.frame = NSRect(x: 22, y: 7, width: 200, height: 24)
        settings.isBordered = false
        settings.font = .systemFont(ofSize: 11)
        settings.contentTintColor = .controlAccentColor
        settings.target = self
        settings.action = #selector(openNotificationSettings)
        settings.isHidden = true
        content.addSubview(settings)
        window.center()
    }

    private func makeMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let show = appMenu.addItem(withTitle: "Show Timer", action: #selector(showWindow), keyEquivalent: "")
        show.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Timeglass", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "Edit")
        for (name, action, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: name, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = edit
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if active == nil && pendingID == nil { window.makeFirstResponder(entry) }
        tick()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { window.orderOut(nil); return false }
    func windowDidResignKey(_ notification: Notification) { window.orderOut(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func openNotificationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }

    private func toggleTimer() {
        if active != nil || pendingID != nil { stop(); return }
        let input = entry.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let seconds = DurationParser.seconds(input) else {
            hint.stringValue = "Try 10m, 90s or 1h 30m. A number alone means minutes."
            return
        }
        let id = UUID().uuidString
        let token = UUID()
        generation = token
        pendingID = id
        entry.isEnabled = false
        hint.stringValue = "Preparing timer… Enter to cancel"
        settings.isHidden = true
        Task { @MainActor in
            do {
                let allowed = try await center.requestAuthorization(options: [.alert, .sound])
                guard generation == token else { return }
                guard allowed else {
                    pendingID = nil
                    entry.isEnabled = true
                    hint.stringValue = "Allow notifications in macOS to start a timer."
                    settings.isHidden = false
                    window.makeKeyAndOrderFront(nil)
                    return
                }
                let timer = ActiveTimer(id: id, deadline: Date().addingTimeInterval(seconds), input: input)
                let content = UNMutableNotificationContent()
                content.title = "Time's up"
                content.body = "Your \(input) timer has finished."
                content.sound = .default
                let request = UNNotificationRequest(identifier: id, content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
                try await center.add(request)
                guard generation == token else {
                    center.removePendingNotificationRequests(withIdentifiers: [id])
                    return
                }
                try store.save(timer)
                active = timer
                pendingID = nil
                entry.isHidden = true
                clock.isHidden = false
                title.stringValue = "\(input) timer"
                hint.stringValue = "Enter to stop · Esc to hide"
                let notificationSettings = await center.notificationSettings()
                if generation == token && active != nil && notificationSettings.soundSetting != .enabled {
                    hint.stringValue = "Enter to stop · Notification sound is disabled in macOS"
                    settings.isHidden = false
                }
                tick()
            } catch {
                center.removePendingNotificationRequests(withIdentifiers: [id])
                guard generation == token else { return }
                pendingID = nil
                entry.isEnabled = true
                hint.stringValue = "Could not start timer: \(error.localizedDescription)"
            }
        }
    }

    private func stop() {
        generation = UUID()
        let ids = [active?.id, pendingID].compactMap { $0 }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        active = nil
        pendingID = nil
        reset("Timer stopped · Enter to start again")
        do { try store.save(nil) }
        catch { hint.stringValue = "Timer stopped. Could not clear its saved state." }
    }

    private func reset(_ message: String) {
        entry.isEnabled = true
        entry.isHidden = false
        clock.isHidden = true
        title.stringValue = "Timeglass"
        hint.stringValue = message
        settings.isHidden = true
        if window.isKeyWindow { window.makeFirstResponder(entry); entry.selectText(nil) }
    }

    private func tick() {
        guard let timer = active else { return }
        let remaining = timer.remaining()
        clock.stringValue = countdown(remaining)
        if remaining == 0 {
            active = nil
            try? store.save(nil)
            reset("Time's up · Enter to start again")
            // macOS delivers the scheduled notification and sound, even if the
            // panel is hidden or the process was quit. Never play a second sound.
        }
    }

    private func restore() {
        do {
            guard let timer = try store.load() else { return }
            entry.stringValue = timer.input
            guard timer.remaining() > 0 else {
                try store.save(nil)
                hint.stringValue = "Time's up · Enter to start again"
                return
            }
            let token = generation
            // Make Enter cancel the saved timer immediately, even while the
            // native notification service is still checking its pending list.
            active = timer
            title.stringValue = "\(timer.input) timer"
            entry.isHidden = true
            clock.isHidden = false
            hint.stringValue = "Enter to stop · Esc to hide"
            tick()
            Task { @MainActor in
                let requests = await center.pendingNotificationRequests()
                guard generation == token, active?.id == timer.id else { return }
                if !requests.contains(where: { $0.identifier == timer.id }) {
                    active = nil
                    try? store.save(nil)
                    reset("Enter to start · Esc to hide")
                }
            }
        } catch { hint.stringValue = "Could not restore the previous timer. Enter a new duration." }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

@main struct Timeglass {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--notification-status") {
            let group = DispatchGroup()
            let center = UNUserNotificationCenter.current()
            group.enter()
            center.getNotificationSettings { settings in
                print("authorization=\(settings.authorizationStatus.rawValue) sound=\(settings.soundSetting.rawValue)")
                group.leave()
            }
            group.enter()
            center.getPendingNotificationRequests { requests in
                print("pending=\(requests.count) withSound=\(requests.filter { $0.content.sound != nil }.count)")
                group.leave()
            }
            group.enter()
            center.getDeliveredNotifications { notifications in
                print("delivered=\(notifications.count) withSound=\(notifications.filter { $0.request.content.sound != nil }.count)")
                group.leave()
            }
            if group.wait(timeout: .now() + 10) == .timedOut { exit(1) }
            return
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
