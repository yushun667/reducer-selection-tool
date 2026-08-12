import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 1720, height: 1150)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "减速器选型计算工具"
        window.minSize = NSSize(width: 1240, height: 800)
        window.center()

        // JS ↔ 原生桥：一键生成零件（选择保存位置 → 后台调 freecadcmd → 直接出 STEP）
        let ucc = WKUserContentController()
        ucc.add(self, name: "genParts")
        let config = WKWebViewConfiguration()
        config.userContentController = ucc

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(webView)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            // 允许读取同目录资源（原理讲解页 planetary_gear_params.html 的链接）
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            let label = NSTextField(labelWithString: "未找到 index.html")
            label.frame = window.contentView!.bounds.insetBy(dx: 40, dy: 40)
            window.contentView!.addSubview(label)
        }
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - 一键生成零件（JS 调用 window.webkit.messageHandlers.genParts.postMessage）

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "genParts",
              let body = message.body as? [String: Any],
              let script = body["script"] as? String else { return }
        let panel = NSOpenPanel()
        panel.title = "选择零件保存位置"
        panel.message = "零件 STEP 将输出到所选文件夹下的 rv-parts/"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "保存到这里"
        panel.begin { [weak self] resp in
            guard let self = self, resp == .OK, let dir = panel.url else { return }
            self.runGenerator(script: script, in: dir)
        }
    }

    func runGenerator(script: String, in dir: URL) {
        let freecadcmd = "/Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd"
        guard FileManager.default.fileExists(atPath: freecadcmd) else {
            showAlert("未找到 FreeCAD", "需要安装 FreeCAD：/Applications/FreeCAD.app")
            return
        }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gen_rv_parts_\(Int(Date().timeIntervalSince1970)).py")
        do {
            try script.write(to: tmp, atomically: true, encoding: .utf8)
        } catch {
            showAlert("脚本写入失败", error.localizedDescription)
            return
        }
        window.title = "减速器选型计算工具（正在生成零件…）"
        DispatchQueue.global().async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: freecadcmd)
            proc.arguments = [tmp.path]
            proc.currentDirectoryURL = dir
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            do {
                try proc.run()
            } catch {
                DispatchQueue.main.async {
                    self.window.title = "减速器选型计算工具"
                    self.showAlert("启动 freecadcmd 失败", error.localizedDescription)
                }
                return
            }
            proc.waitUntilExit()
            let log = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                             encoding: .utf8) ?? ""
            try? log.write(to: dir.appendingPathComponent("rv-parts-gen.log"),
                           atomically: true, encoding: .utf8)
            DispatchQueue.main.async {
                self.window.title = "减速器选型计算工具"
                try? FileManager.default.removeItem(at: tmp)
                if proc.terminationStatus == 0 && log.contains("DONE") {
                    let lines = log.split(separator: "\n")
                        .filter { $0.hasPrefix("EXPORT") }
                        .map { $0.replacingOccurrences(of: "EXPORT ", with: "") }
                        .joined(separator: "\n")
                    self.showAlert("零件已生成 ✓",
                                   "位置：\(dir.path)/rv-parts/\n\n\(lines)")
                } else {
                    self.showAlert("生成失败", String(log.suffix(800)))
                }
            }
        }
    }

    func showAlert(_ title: String, _ msg: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = msg
        a.alertStyle = .informational
        a.addButton(withTitle: "好")
        a.runModal()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
