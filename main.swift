import AppKit

// MARK: - Browser model

struct Browser {
    let url: URL
    let bundleID: String
    let name: String
}

enum Browsers {
    static func all() -> [Browser] {
        let ws = NSWorkspace.shared
        let https = Set(ws.urlsForApplications(toOpen: URL(string: "https://example.com")!).map(\.standardizedFileURL))
        var seen = Set<String>()
        return ws.urlsForApplications(toOpen: URL(string: "http://example.com")!)
            .map(\.standardizedFileURL)
            .filter { https.contains($0) }
            .compactMap { url -> Browser? in
                guard let b = Bundle(url: url), let id = b.bundleIdentifier?.lowercased(),
                      seen.insert(id).inserted else { return nil }
                let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
                return Browser(url: url, bundleID: id, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func currentID() -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) else { return nil }
        return Bundle(url: url)?.bundleIdentifier?.lowercased()
    }

    /// Completion runs after the user answers the macOS confirmation prompt.
    static func setDefault(_ b: Browser, done: @escaping (Error?) -> Void) {
        let ws = NSWorkspace.shared
        ws.setDefaultApplication(at: b.url, toOpenURLsWithScheme: "http") { err in
            if let err { return DispatchQueue.main.async { done(err) } }
            ws.setDefaultApplication(at: b.url, toOpenURLsWithScheme: "https") { err in
                DispatchQueue.main.async { done(err) }
            }
        }
    }
}

// MARK: - Switcher view (vertical list)

final class SwitcherView: NSView {
    let browsers: [Browser]
    let currentID: String?
    var selected: Int
    var busy = false
    var onCommit: ((Browser) -> Void)?
    var onCancel: (() -> Void)?

    static let width: CGFloat = 380, rowH: CGFloat = 52, pad: CGFloat = 12, header: CGFloat = 40, footer: CGFloat = 36

    init(browsers: [Browser], currentID: String?) {
        self.browsers = browsers
        self.currentID = currentID
        self.selected = browsers.firstIndex { $0.bundleID == currentID } ?? 0
        let h = Self.header + CGFloat(browsers.count) * Self.rowH + Self.footer + Self.pad
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: h))
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    func rowRect(_ i: Int) -> NSRect {
        NSRect(x: Self.pad, y: Self.header + CGFloat(i) * Self.rowH, width: bounds.width - 2 * Self.pad, height: Self.rowH)
    }

    override func draw(_ dirty: NSRect) {
        let center = NSMutableParagraphStyle(); center.alignment = .center
        ("Default Browser" as NSString).draw(
            in: NSRect(x: 0, y: 14, width: bounds.width, height: 20),
            withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                             .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: center])

        for (i, b) in browsers.enumerated() {
            let r = rowRect(i)
            let isSel = i == selected
            let isCurrent = b.bundleID == currentID

            if isSel {
                NSColor.controlAccentColor.setFill()
                NSBezierPath(roundedRect: r.insetBy(dx: 0, dy: 2), xRadius: 10, yRadius: 10).fill()
            }

            let iconSize: CGFloat = 34
            NSWorkspace.shared.icon(forFile: b.url.path)
                .draw(in: NSRect(x: r.minX + 10, y: r.midY - iconSize / 2, width: iconSize, height: iconSize))

            let textColor: NSColor = isSel ? .white : .labelColor
            let font = NSFont.systemFont(ofSize: 15, weight: isSel ? .semibold : .regular)
            let nameH = font.ascender - font.descender
            (b.name as NSString).draw(
                in: NSRect(x: r.minX + 56, y: r.midY - nameH / 2, width: r.width - 56 - 96, height: nameH),
                withAttributes: [.font: font, .foregroundColor: textColor])

            if isCurrent {
                // "✓ Current" pill on the right
                let label = "✓ Current" as NSString
                let f = NSFont.systemFont(ofSize: 11, weight: .bold)
                let size = label.size(withAttributes: [.font: f])
                let pill = NSRect(x: r.maxX - size.width - 26, y: r.midY - 11, width: size.width + 16, height: 22)
                (isSel ? NSColor.white.withAlphaComponent(0.25) : NSColor.systemGreen.withAlphaComponent(0.2)).setFill()
                NSBezierPath(roundedRect: pill, xRadius: 11, yRadius: 11).fill()
                label.draw(at: NSPoint(x: pill.minX + 8, y: pill.midY - size.height / 2),
                           withAttributes: [.font: f, .foregroundColor: isSel ? NSColor.white : NSColor.systemGreen])
            }
        }

        let hint = busy ? "Confirm the change in the macOS dialog…"
                        : "↑ ↓ choose    ↩ set as default    esc cancel"
        (hint as NSString).draw(
            in: NSRect(x: 0, y: bounds.height - Self.footer + 6, width: bounds.width, height: 18),
            withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor,
                             .paragraphStyle: center])
    }

    func move(_ d: Int) {
        guard !browsers.isEmpty else { return }
        selected = (selected + d + browsers.count) % browsers.count
        needsDisplay = true
    }

    func commit() {
        guard !busy, browsers.indices.contains(selected) else { return }
        busy = true; needsDisplay = true
        onCommit?(browsers[selected])
    }

    override func keyDown(with e: NSEvent) {
        if busy { return }
        switch Int(e.keyCode) {
        case 126, 123: move(-1)            // ↑ ←
        case 125, 124, 48: move(1)         // ↓ → tab
        case 36, 76, 49: commit()          // return, enter, space
        case 53: onCancel?()               // esc
        default:
            if let c = e.charactersIgnoringModifiers, let n = Int(c), (1...browsers.count).contains(n) {
                selected = n - 1; needsDisplay = true
            } else { super.keyDown(with: e) }
        }
    }

    override func mouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        guard !busy, let i = browsers.indices.first(where: { rowRect($0).contains(p) }) else { return }
        selected = i; needsDisplay = true
        if e.clickCount == 2 { commit() }
    }
}

// MARK: - Window & app

final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: KeyWindow!

    func applicationDidFinishLaunching(_ n: Notification) {
        let view = SwitcherView(browsers: Browsers.all(), currentID: Browsers.currentID())
        view.onCancel = { NSApp.terminate(nil) }
        view.onCommit = { b in
            if b.bundleID == view.currentID { return NSApp.terminate(nil) }   // already default: nothing to do
            Browsers.setDefault(b) { err in
                if let err { NSLog("Default Browser Switcher: \(err.localizedDescription)") }
                NSApp.terminate(nil)                                         // prompt answered → quit
            }
        }

        window = KeyWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isMovableByWindowBackground = true

        let fx = NSVisualEffectView(frame: view.frame)
        fx.material = .hudWindow
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 16
        fx.layer?.masksToBounds = true
        fx.addSubview(view)
        window.contentView = fx

        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
