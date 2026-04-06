import Cocoa
import WebKit
import Speech
import AVFoundation

// MARK: - Text extraction for speech matching

func extractPlainWords(_ markdown: String) -> [String] {
    // Strip markdown syntax to get plain words for matching
    var text = markdown
    // Remove code blocks
    let codeBlockPattern = try! NSRegularExpression(pattern: "```[\\s\\S]*?```", options: [])
    text = codeBlockPattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
    // Remove inline code
    let inlineCodePattern = try! NSRegularExpression(pattern: "`[^`]+`", options: [])
    text = inlineCodePattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
    // Remove markdown symbols
    let symbolPattern = try! NSRegularExpression(pattern: "[#*_\\[\\]()>|~`]", options: [])
    text = symbolPattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    // Remove link URLs
    let urlPattern = try! NSRegularExpression(pattern: "https?://\\S+", options: [])
    text = urlPattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    // Remove numbered list prefixes
    let olPattern = try! NSRegularExpression(pattern: "^\\d+\\.", options: .anchorsMatchLines)
    text = olPattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    // Split into words, lowercase, remove punctuation for matching
    return text.components(separatedBy: .whitespacesAndNewlines)
        .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
        .filter { !$0.isEmpty }
}

// MARK: - Markdown to HTML (with word spans)

func markdownToHTML(_ markdown: String, wrapWords: Bool = false) -> String {
    let lines = markdown.components(separatedBy: "\n")
    var html = ""
    var inCodeBlock = false
    var inList = false
    var listType = ""
    var wordIndex = 0

    func wrapWordsInSpans(_ text: String) -> String {
        guard wrapWords else { return text }
        var result = ""
        var i = text.startIndex
        while i < text.endIndex {
            // Skip HTML tags
            if text[i] == "<" {
                if let closeIdx = text[i...].firstIndex(of: ">") {
                    result += String(text[i...closeIdx])
                    i = text.index(after: closeIdx)
                    continue
                }
            }
            // Collect a word
            if !text[i].isWhitespace {
                var wordEnd = i
                while wordEnd < text.endIndex && !text[wordEnd].isWhitespace && text[wordEnd] != "<" {
                    wordEnd = text.index(after: wordEnd)
                }
                let word = String(text[i..<wordEnd])
                result += "<span class=\"w\" id=\"w\(wordIndex)\">\(word)</span>"
                wordIndex += 1
                i = wordEnd
            } else {
                result += String(text[i])
                i = text.index(after: i)
            }
        }
        return result
    }

    func processInline(_ text: String) -> String {
        var result = text
        let boldItalicPattern = try! NSRegularExpression(pattern: "\\*\\*\\*(.+?)\\*\\*\\*")
        result = boldItalicPattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "<strong><em>$1</em></strong>")
        let boldPattern = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*")
        result = boldPattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "<strong>$1</strong>")
        let italicPattern = try! NSRegularExpression(pattern: "\\*(.+?)\\*")
        result = italicPattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "<em>$1</em>")
        let codePattern = try! NSRegularExpression(pattern: "`(.+?)`")
        result = codePattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "<code>$1</code>")
        let linkPattern = try! NSRegularExpression(pattern: "\\[(.+?)\\]\\((.+?)\\)")
        result = linkPattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "<a href=\"$2\">$1</a>")
        return wrapWordsInSpans(result)
    }

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("```") {
            if inCodeBlock {
                html += "</code></pre>"
                inCodeBlock = false
            } else {
                if inList { html += "</\(listType)>"; inList = false }
                inCodeBlock = true
                html += "<pre><code>"
            }
            continue
        }
        if inCodeBlock {
            html += trimmed.replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;") + "\n"
            continue
        }

        if trimmed.isEmpty {
            if inList { html += "</\(listType)>"; inList = false }
            continue
        }

        for level in (1...6).reversed() {
            let prefix = String(repeating: "#", count: level) + " "
            if trimmed.hasPrefix(prefix) {
                if inList { html += "</\(listType)>"; inList = false }
                html += "<h\(level)>\(processInline(String(trimmed.dropFirst(level + 1).trimmingCharacters(in: .whitespaces))))</h\(level)>"
                break
            }
        }
        if trimmed.hasPrefix("#") { continue }

        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            if inList { html += "</\(listType)>"; inList = false }
            html += "<hr>"
            continue
        }

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            if !inList || listType != "ul" {
                if inList { html += "</\(listType)>" }
                html += "<ul>"
                inList = true
                listType = "ul"
            }
            html += "<li>\(processInline(String(trimmed.dropFirst(2))))</li>"
            continue
        }

        let olPattern = try! NSRegularExpression(pattern: "^\\d+\\. ")
        if olPattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            if !inList || listType != "ol" {
                if inList { html += "</\(listType)>" }
                html += "<ol>"
                inList = true
                listType = "ol"
            }
            let content = trimmed.replacingOccurrences(of: "^\\d+\\. ", with: "", options: .regularExpression)
            html += "<li>\(processInline(content))</li>"
            continue
        }

        if trimmed.hasPrefix("> ") {
            if inList { html += "</\(listType)>"; inList = false }
            html += "<blockquote>\(processInline(String(trimmed.dropFirst(2))))</blockquote>"
            continue
        }

        if inList { html += "</\(listType)>"; inList = false }
        html += "<p>\(processInline(trimmed))</p>"
    }

    if inList { html += "</\(listType)>" }
    if inCodeBlock { html += "</code></pre>" }

    return html
}

func buildHTMLPage(markdownContent: String) -> String {
    let bodyHTML = markdownToHTML(markdownContent, wrapWords: true)
    return """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body {
            background: transparent;
            height: 100%;
            overflow: hidden;
        }
        #container {
            background: rgba(0, 0, 0, 0.7);
            color: #f0f0f0;
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif;
            font-size: 28px;
            line-height: 1.6;
            padding: 40px 50px;
            padding-top: 50px;
            height: 100%;
            overflow-y: auto;
            -webkit-font-smoothing: antialiased;
        }
        #container.mirrored { transform: scaleX(-1); }
        #container.dark-mode { color: #1a1a1a; }
        #container.dark-mode strong { color: #000; }
        #container.dark-mode h1, #container.dark-mode h2 { color: #000; }
        #container.dark-mode h3 { color: #111; }
        #container.dark-mode h4, #container.dark-mode h5, #container.dark-mode h6 { color: #222; }
        #container.dark-mode blockquote { color: #333; border-left-color: rgba(0,0,0,0.3); }
        #container.dark-mode a { color: #0055aa; }
        #container.dark-mode code { color: #1a1a1a; }
        #container.dark-mode :not(pre) > code { background: rgba(0,0,0,0.08); }
        #container.dark-mode pre { background: rgba(0,0,0,0.08); }

        #container::-webkit-scrollbar { width: 6px; }
        #container::-webkit-scrollbar-track { background: transparent; }
        #container::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.2); border-radius: 3px; }

        /* Word highlighting for speech tracking */
        .w.spoken { opacity: 0.45; }
        .w.current { background: rgba(255,255,100,0.25); border-radius: 3px; }

        /* Top bar */
        #top-bar {
            position: fixed;
            top: 0; left: 0; right: 0;
            height: 36px;
            background: linear-gradient(to bottom, rgba(255,255,255,0.1), rgba(255,255,255,0.03));
            z-index: 100;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 10px;
            -webkit-app-region: drag;
        }
        #top-bar .left, #top-bar .right {
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .bar-btn {
            -webkit-app-region: no-drag;
            background: rgba(255,255,255,0.12);
            color: rgba(255,255,255,0.7);
            border: none;
            border-radius: 4px;
            padding: 3px 10px;
            font-size: 12px;
            font-family: -apple-system, sans-serif;
            cursor: pointer;
            transition: background 0.2s;
        }
        .bar-btn:hover { background: rgba(255,255,255,0.22); color: #fff; }
        .bar-btn.active { background: rgba(100,200,255,0.3); color: #fff; }

        #opacity-slider {
            -webkit-app-region: no-drag;
            width: 80px;
            height: 4px;
            -webkit-appearance: none;
            appearance: none;
            background: rgba(255,255,255,0.2);
            border-radius: 2px;
            outline: none;
            cursor: pointer;
        }
        #opacity-slider::-webkit-slider-thumb {
            -webkit-appearance: none;
            width: 14px; height: 14px;
            background: rgba(255,255,255,0.8);
            border-radius: 50%;
            cursor: pointer;
        }
        .slider-label {
            font-size: 11px;
            color: rgba(255,255,255,0.5);
            font-family: "SF Mono", monospace;
        }

        h1 { font-size: 2em; font-weight: 700; margin: 0.8em 0 0.4em; color: #fff; }
        h2 { font-size: 1.6em; font-weight: 600; margin: 0.7em 0 0.3em; color: #fff; }
        h3 { font-size: 1.3em; font-weight: 600; margin: 0.6em 0 0.3em; color: #eee; }
        h4, h5, h6 { font-size: 1.1em; font-weight: 600; margin: 0.5em 0 0.2em; color: #ddd; }
        p { margin: 0.5em 0; }
        ul, ol { margin: 0.5em 0 0.5em 1.5em; }
        li { margin: 0.2em 0; }
        blockquote {
            border-left: 3px solid rgba(255,255,255,0.3);
            padding-left: 1em;
            margin: 0.5em 0;
            color: #ccc;
            font-style: italic;
        }
        pre {
            background: rgba(0,0,0,0.4);
            padding: 1em;
            border-radius: 6px;
            margin: 0.5em 0;
            overflow-x: auto;
        }
        code {
            font-family: "SF Mono", "Menlo", monospace;
            font-size: 0.85em;
        }
        :not(pre) > code {
            background: rgba(255,255,255,0.1);
            padding: 0.15em 0.4em;
            border-radius: 3px;
        }
        a { color: #6cb4ee; text-decoration: none; }
        hr { border: none; border-top: 1px solid rgba(255,255,255,0.2); margin: 1em 0; }
        strong { color: #fff; }

        #status {
            position: fixed;
            bottom: 10px;
            right: 15px;
            font-size: 13px;
            color: rgba(255,255,255,0.4);
            font-family: "SF Mono", monospace;
            z-index: 100;
            pointer-events: none;
            transition: opacity 0.3s;
        }

        #help-overlay {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.85);
            z-index: 150;
            align-items: center;
            justify-content: center;
        }
        #help-overlay.visible { display: flex; }
        #help-content {
            font-family: -apple-system, sans-serif;
            color: #f0f0f0;
            font-size: 15px;
            line-height: 2;
            max-width: 340px;
        }
        #help-content h3 { font-size: 18px; margin-bottom: 12px; color: #fff; }
        .shortcut-row { display: flex; justify-content: space-between; align-items: center; }
        .shortcut-row .label { color: rgba(255,255,255,0.7); }
        .key {
            display: inline-block;
            background: rgba(255,255,255,0.12);
            border: 1px solid rgba(255,255,255,0.2);
            border-radius: 4px;
            padding: 1px 8px;
            font-family: "SF Mono", monospace;
            font-size: 13px;
            color: #fff;
            min-width: 28px;
            text-align: center;
        }
        #help-dismiss { margin-top: 16px; font-size: 13px; color: rgba(255,255,255,0.4); text-align: center; }

        #content { padding-bottom: 60vh; }
    </style>
    </head>
    <body>
        <div id="top-bar">
            <div class="left">
                <button class="bar-btn" onclick="window.webkit.messageHandlers.openFile.postMessage('')" title="Open file">Open</button>
                <button class="bar-btn" id="mic-btn" onclick="window.webkit.messageHandlers.toggleMic.postMessage('')" title="Voice-driven scroll">Mic</button>
            </div>
            <div class="right">
                <span class="slider-label">opacity</span>
                <input type="range" id="opacity-slider" min="5" max="95" value="70" oninput="setOpacity(this.value)">
                <button class="bar-btn" id="color-toggle" onclick="toggleTextColor()" title="Toggle text color">A</button>
                <button class="bar-btn" onclick="toggleHelp()" title="Keyboard shortcuts">?</button>
            </div>
        </div>

        <div id="help-overlay" onclick="toggleHelp()">
            <div id="help-content">
                <h3>Keyboard Shortcuts</h3>
                <div class="shortcut-row"><span class="label">Play / Pause</span><span class="key">Space</span></div>
                <div class="shortcut-row"><span class="label">Speed up</span><span class="key">&uarr;</span></div>
                <div class="shortcut-row"><span class="label">Speed down</span><span class="key">&darr;</span></div>
                <div class="shortcut-row"><span class="label">Bigger font</span><span class="key">]</span></div>
                <div class="shortcut-row"><span class="label">Smaller font</span><span class="key">[</span></div>
                <div class="shortcut-row"><span class="label">More opaque</span><span class="key">=</span></div>
                <div class="shortcut-row"><span class="label">More transparent</span><span class="key">-</span></div>
                <div class="shortcut-row"><span class="label">Reset to top</span><span class="key">R</span></div>
                <div class="shortcut-row"><span class="label">Mirror mode</span><span class="key">M</span></div>
                <div class="shortcut-row"><span class="label">Toggle mic</span><span class="key">V</span></div>
                <div class="shortcut-row"><span class="label">Open file</span><span class="key">O</span></div>
                <div class="shortcut-row"><span class="label">Quit</span><span class="key">Q</span></div>
                <div id="help-dismiss">Click anywhere to close</div>
            </div>
        </div>

        <div id="container">
            <div id="content">\(bodyHTML)</div>
        </div>
        <div id="status"></div>

        <script>
            const container = document.getElementById('container');
            const status = document.getElementById('status');
            let scrolling = false;
            let speed = 1.0;
            let statusTimeout = null;
            let darkMode = false;

            function showStatus(msg) {
                status.textContent = msg;
                status.style.opacity = '1';
                clearTimeout(statusTimeout);
                statusTimeout = setTimeout(() => { status.style.opacity = '0'; }, 2000);
            }

            function scroll() {
                if (scrolling) {
                    container.scrollTop += speed;
                }
                requestAnimationFrame(scroll);
            }
            requestAnimationFrame(scroll);

            function toggleScroll() {
                scrolling = !scrolling;
                showStatus(scrolling ? '\\u25B6 Playing' : '\\u23F8 Paused');
            }
            function adjustSpeed(delta) {
                speed = Math.max(0.2, Math.min(10, speed + delta));
                showStatus('Speed: ' + speed.toFixed(1) + 'x');
            }
            function resetScroll() {
                container.scrollTop = 0;
                // Reset word highlights
                document.querySelectorAll('.w.spoken, .w.current').forEach(el => {
                    el.classList.remove('spoken', 'current');
                });
                showStatus('\\u23EE Reset');
            }
            function toggleMirror() {
                container.classList.toggle('mirrored');
                showStatus(container.classList.contains('mirrored') ? 'Mirrored' : 'Normal');
            }
            function setOpacity(val) {
                container.style.background = 'rgba(0,0,0,' + (val / 100).toFixed(2) + ')';
            }
            function adjustOpacity(delta) {
                let bg = container.style.background || 'rgba(0,0,0,0.7)';
                let match = bg.match(/[\\d.]+\\)/);
                let current = match ? parseFloat(match[0]) : 0.7;
                let next = Math.max(0.05, Math.min(0.95, current + delta));
                container.style.background = 'rgba(0,0,0,' + next.toFixed(2) + ')';
                document.getElementById('opacity-slider').value = Math.round(next * 100);
                showStatus('Opacity: ' + Math.round(next * 100) + '%');
            }
            function adjustFontSize(delta) {
                let current = parseFloat(getComputedStyle(container).fontSize);
                let next = Math.max(14, Math.min(72, current + delta));
                container.style.fontSize = next + 'px';
                showStatus('Font: ' + Math.round(next) + 'px');
            }
            function toggleTextColor() {
                darkMode = !darkMode;
                container.classList.toggle('dark-mode', darkMode);
                document.getElementById('color-toggle').classList.toggle('active', darkMode);
                showStatus(darkMode ? 'Black text' : 'White text');
            }
            function toggleHelp() {
                document.getElementById('help-overlay').classList.toggle('visible');
            }
            function updateContent(html) {
                document.getElementById('content').innerHTML = html;
                container.scrollTop = 0;
                scrolling = false;
                showStatus('\\u23F8 Paused \\u2014 Space to start');
            }

            // Speech tracking
            function setMicActive(active) {
                document.getElementById('mic-btn').classList.toggle('active', active);
                if (active) {
                    scrolling = false; // disable auto-scroll when mic is active
                    showStatus('\\uD83C\\uDF99 Listening...');
                } else {
                    showStatus('\\uD83C\\uDF99 Mic off');
                }
            }
            let lastScrollTarget = 0;
            function scrollToWord(index) {
                // Mark previous words as spoken
                for (let i = 0; i < index; i++) {
                    let el = document.getElementById('w' + i);
                    if (el) {
                        el.classList.add('spoken');
                        el.classList.remove('current');
                    }
                }
                // Highlight current word
                let current = document.getElementById('w' + index);
                if (current) {
                    document.querySelectorAll('.w.current').forEach(el => el.classList.remove('current'));
                    current.classList.add('current');
                    // Smooth scroll so current word is ~1/3 from top
                    let containerRect = container.getBoundingClientRect();
                    let wordRect = current.getBoundingClientRect();
                    let targetY = containerRect.top + containerRect.height * 0.33;
                    let newTarget = container.scrollTop + (wordRect.top - targetY);
                    if (Math.abs(newTarget - lastScrollTarget) > 5) {
                        lastScrollTarget = newTarget;
                        container.scrollTo({ top: newTarget, behavior: 'smooth' });
                    }
                }
            }

            showStatus('\\u23F8 Paused \\u2014 Space to start');
        </script>
    </body>
    </html>
    """
}

// MARK: - Draggable View

class DragHandleView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if local.x < 120 || local.x > bounds.width - 260 {
            return nil
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - Script Message Handler

class MessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: AppDelegate?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "openFile" {
            delegate?.openFilePicker()
        } else if message.name == "toggleMic" {
            delegate?.toggleSpeechRecognition()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var markdownContent: String = ""
    var messageHandler: MessageHandler!

    // Speech recognition
    var speechRecognizer: SFSpeechRecognizer?
    var audioEngine: AVAudioEngine?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var isListening = false
    var plainWords: [String] = []
    var wordPointer = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main!
        let width: CGFloat = 600
        let height: CGFloat = 800
        let x = screen.frame.width - width - 40
        let y = (screen.frame.height - height) / 2

        window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // WebView with message handlers
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        messageHandler = MessageHandler()
        messageHandler.delegate = self
        config.userContentController.add(messageHandler, name: "openFile")
        config.userContentController.add(messageHandler, name: "toggleMic")

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        window.contentView!.addSubview(webView)

        // Native drag handle
        let dragHandle = DragHandleView(frame: NSRect(x: 0, y: window.contentView!.bounds.height - 36, width: window.contentView!.bounds.width, height: 36))
        dragHandle.autoresizingMask = [.width, .minYMargin]
        dragHandle.wantsLayer = true
        window.contentView!.addSubview(dragHandle, positioned: .above, relativeTo: webView)

        loadContent()

        window.ignoresMouseEvents = true
        window.makeKeyAndOrderFront(nil)

        // Mouse tracking for click-through
        let edgeMargin: CGFloat = 8
        let topBarHeight: CGFloat = 36
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.updateClickThrough(edgeMargin: edgeMargin, topBarHeight: topBarHeight)
        }
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updateClickThrough(edgeMargin: edgeMargin, topBarHeight: topBarHeight)
            return event
        }

        // Open file picker if no content
        if markdownContent.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openFilePicker()
            }
        }

        // Keyboard handling
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            switch event.keyCode {
            case 49: // Space
                self.webView.evaluateJavaScript("toggleScroll()")
                return nil
            case 126: // Up
                self.webView.evaluateJavaScript("adjustSpeed(0.3)")
                return nil
            case 125: // Down
                self.webView.evaluateJavaScript("adjustSpeed(-0.3)")
                return nil
            case 15: // R
                self.webView.evaluateJavaScript("resetScroll()")
                self.wordPointer = 0
                return nil
            case 46: // M
                self.webView.evaluateJavaScript("toggleMirror()")
                return nil
            case 53, 12: // Esc or Q
                NSApplication.shared.terminate(nil)
                return nil
            case 27: // -
                self.webView.evaluateJavaScript("adjustOpacity(-0.05)")
                return nil
            case 24: // =
                self.webView.evaluateJavaScript("adjustOpacity(0.05)")
                return nil
            case 30: // ]
                self.webView.evaluateJavaScript("adjustFontSize(2)")
                return nil
            case 33: // [
                self.webView.evaluateJavaScript("adjustFontSize(-2)")
                return nil
            case 31: // O
                self.openFilePicker()
                return nil
            case 9: // V
                self.toggleSpeechRecognition()
                return nil
            default:
                return event
            }
        }

        // Initialize speech recognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        audioEngine = AVAudioEngine()
    }

    func loadContent() {
        plainWords = extractPlainWords(markdownContent)
        wordPointer = 0
        let htmlString = buildHTMLPage(markdownContent: markdownContent)
        webView.loadHTMLString(htmlString, baseURL: nil)
    }

    func updateClickThrough(edgeMargin: CGFloat, topBarHeight: CGFloat) {
        let mouseScreen = NSEvent.mouseLocation
        let frame = window.frame
        guard frame.contains(mouseScreen) else {
            window.ignoresMouseEvents = true
            return
        }
        let localX = mouseScreen.x - frame.origin.x
        let localY = mouseScreen.y - frame.origin.y
        let nearTop = localY > frame.height - topBarHeight
        let nearEdge = localX < edgeMargin || localX > frame.width - edgeMargin
            || localY < edgeMargin || localY > frame.height - edgeMargin
        window.ignoresMouseEvents = !(nearTop || nearEdge)
    }

    func openFilePicker() {
        // Temporarily disable click-through for the panel
        window.ignoresMouseEvents = false
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open Markdown File"
        panel.level = .floating

        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                markdownContent = content
                loadContent()
            }
        }
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Speech Recognition

    func toggleSpeechRecognition() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            webView.evaluateJavaScript("showStatus('Speech recognition unavailable')")
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch status {
                case .authorized:
                    self.beginRecognition()
                default:
                    self.webView.evaluateJavaScript("showStatus('Microphone permission denied')")
                }
            }
        }
    }

    func beginRecognition() {
        guard let audioEngine = audioEngine, let speechRecognizer = speechRecognizer else { return }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let spokenText = result.bestTranscription.formattedString.lowercased()
                let spokenWords = spokenText.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                    .filter { !$0.isEmpty }
                self.matchSpokenWords(spokenWords)
            }

            if error != nil || (result?.isFinal ?? false) {
                // Restart recognition to keep listening
                if self.isListening {
                    self.restartRecognition()
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            webView.evaluateJavaScript("setMicActive(true)")
        } catch {
            webView.evaluateJavaScript("showStatus('Audio engine error')")
        }
    }

    func restartRecognition() {
        guard let audioEngine = audioEngine else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        // Brief delay then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.isListening else { return }
            self.beginRecognition()
        }
    }

    func stopListening() {
        isListening = false
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        webView.evaluateJavaScript("setMicActive(false)")
    }

    var missCount = 0

    func matchSpokenWords(_ spokenWords: [String]) {
        guard spokenWords.count >= 2, !plainWords.isEmpty else { return }

        let windowSize = min(8, spokenWords.count)
        let recentSpoken = Array(spokenWords.suffix(windowSize))

        // First pass: search nearby (smooth following)
        let nearEnd = min(wordPointer + 40, plainWords.count)
        if let pos = findBestMatch(recentSpoken, from: wordPointer, to: nearEnd, threshold: 3) {
            missCount = 0
            advanceTo(pos + recentSpoken.count)
            return
        }

        // Track consecutive misses
        missCount += 1

        // After a few misses, search the entire remaining text (user skipped ahead)
        if missCount >= 3 {
            let farStart = min(wordPointer + 40, plainWords.count)
            if let pos = findBestMatch(recentSpoken, from: farStart, to: plainWords.count, threshold: 4) {
                missCount = 0
                advanceTo(pos + recentSpoken.count)
                return
            }

            // Also search backward in case user jumped to an earlier section
            if wordPointer > 0 {
                if let pos = findBestMatch(recentSpoken, from: 0, to: wordPointer, threshold: 4) {
                    missCount = 0
                    wordPointer = min(pos + recentSpoken.count, plainWords.count - 1)
                    DispatchQueue.main.async {
                        self.webView.evaluateJavaScript("scrollToWord(\(self.wordPointer))")
                    }
                    return
                }
            }
        }
    }

    func findBestMatch(_ spoken: [String], from: Int, to: Int, threshold: Int) -> Int? {
        var bestPos = -1
        var bestScore = 0

        for i in from..<to {
            var total = 0
            for (j, word) in spoken.enumerated() {
                let textIdx = i + j
                guard textIdx < plainWords.count else { break }
                if fuzzyMatch(word, plainWords[textIdx]) {
                    total += 1
                }
            }
            if total >= threshold && total > bestScore {
                bestScore = total
                bestPos = i
            }
        }
        return bestPos >= 0 ? bestPos : nil
    }

    func advanceTo(_ pos: Int) {
        let newPointer = min(pos, plainWords.count - 1)
        if newPointer > wordPointer {
            wordPointer = newPointer
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript("scrollToWord(\(self.wordPointer))")
            }
        }
    }

    func fuzzyMatch(_ spoken: String, _ text: String) -> Bool {
        if spoken == text { return true }
        if spoken.isEmpty || text.isEmpty { return false }
        // Exact prefix match (handles partial recognition like "tele" for "teleprompter")
        if spoken.count >= 3 && (spoken.hasPrefix(text) || text.hasPrefix(spoken)) { return true }
        // Levenshtein-ish: for words of similar length, check character overlap
        let lenDiff = abs(spoken.count - text.count)
        if lenDiff <= 2 && spoken.count >= 3 && text.count >= 3 {
            let sChars = Array(spoken)
            let tChars = Array(text)
            let minLen = min(sChars.count, tChars.count)
            var matches = 0
            for k in 0..<minLen {
                if sChars[k] == tChars[k] { matches += 1 }
            }
            return Double(matches) / Double(max(sChars.count, tChars.count)) >= 0.6
        }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()

if CommandLine.arguments.count > 1 {
    let filePath = CommandLine.arguments[1]
    if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
        delegate.markdownContent = content
    } else {
        print("Error: Cannot read file '\(filePath)'")
        exit(1)
    }
}

app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
