import AppKit
import QuartzCore
import SwiftUI

enum InputMode: String, CaseIterable, Identifiable {
    case lid = "화면 각도"
    case manual = "수동 연주"
    var id: Self { self }
}

final class InstrumentModel: ObservableObject {
    @Published var theme: InstrumentTheme {
        didSet { preferences.set(theme.rawValue, forKey: InstrumentTheme.preferenceKey) }
    }
    private let preferences: UserDefaults
    @Published var inputMode: InputMode = .lid { didSet { updatePitchLevel(); updateSound() } }
    @Published var lidAngle = 120.0 { didSet { updatePitchLevel(); updateSound() } }
    @Published var manualAngle = 100.0 { didSet { updatePitchLevel(); updateSound() } }
    @Published var mouth = 0.5 { didSet { updateSound() } }
    @Published var mouthMotionEnabled = true
    @Published private(set) var pitchLevel = 3
    @Published var isPlaying = false { didSet { updateSound() } }
    @Published var sensorConnected = false
    @Published var statusMessage = "화면 각도 센서 확인 중…"
    @Published var audioError: String?

    private let sensor = LidSensor()
    private let synth = OtamatoneSynth()
    private var hasStarted = false

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        self.theme = InstrumentTheme.saved(in: preferences)
        sensor.onAngle = { [weak self] value in
            self?.lidAngle = value
        }
        sensor.onStatus = { [weak self] connected, message in
            guard let self else { return }
            self.sensorConnected = connected
            self.statusMessage = message
            if !connected && self.inputMode == .lid { self.inputMode = .manual }
            self.updateSound()
        }
    }

    var activeAngle: Double { inputMode == .lid ? lidAngle : manualAngle }
    var safeToPlay: Bool { inputMode == .manual || (sensorConnected && lidAngle >= 25) }
    var normalizedPitch: Double { min(max((activeAngle - 55) / 90, 0), 1) }
    var visualMouthLevel: Int { mouthMotionEnabled ? pitchLevel : 0 }
    var midiPitch: Double { 48 + normalizedPitch * 36 }
    var frequency: Double { 440 * pow(2, (midiPitch - 69) / 12) }
    var noteName: String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let note = Int(midiPitch.rounded())
        return "\(names[note % 12])\(note / 12 - 1)"
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        sensor.start()
    }

    func togglePlay() {
        if isPlaying { isPlaying = false; return }
        guard safeToPlay else { return }
        do {
            try synth.start()
            audioError = nil
            isPlaying = true
        } catch {
            audioError = "오디오 출력 장치를 시작할 수 없습니다: \(error.localizedDescription)"
        }
    }

    func stop() {
        isPlaying = false
        synth.stop()
        sensor.stop()
        hasStarted = false
    }

    private func updatePitchLevel() {
        // Keep the current image until the angle is safely past a level boundary.
        // This prevents sensor noise from switching two images every 33 ms.
        let margin = 2.0 / 90.0
        let pitch = normalizedPitch
        var next = pitchLevel
        while next < 4 && pitch >= Double(next + 1) / 5.0 + margin { next += 1 }
        while next > 0 && pitch < Double(next) / 5.0 - margin { next -= 1 }
        if next != pitchLevel { pitchLevel = next }
    }

    private func updateSound() {
        synth.set(frequency: frequency, mouth: mouth, playing: isPlaying && safeToPlay)
    }
}

#if !THEME_CHECKS
@main
struct MactamatoneApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = MactamatoneDelegate()
        app.delegate = delegate
        app.run()
    }
}

#endif

private final class MactamatoneDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = InstrumentModel()
    private var widgetWindow: NSPanel?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = NSSize(width: 320, height: 476)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(x: screen.maxX - size.width - 32,
                             y: screen.midY - size.height / 2)
        let widget = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        widget.title = "맥타마톤"
        widget.level = .floating
        widget.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        widget.isOpaque = false
        widget.backgroundColor = .clear
        widget.hasShadow = false
        widget.hidesOnDeactivate = false
        widget.isMovableByWindowBackground = false
        widget.contentView = NSHostingView(rootView: FloatingWidgetView(
            model: model,
            openSettings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }
        ).frame(width: size.width, height: size.height))
        widget.delegate = self
        widget.orderFrontRegardless()
        widgetWindow = widget
        model.start()
    }

    private func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = SettingsWindow(model: model)
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow {
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, self.settingsWindow === window else { return }
                self.settingsWindow = nil
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) { model.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// Keep native window controls while letting the theme fill the titlebar area.
final class SettingsWindow: NSWindow {
    static let trafficLightInset: CGFloat = 32

    init(model: InstrumentModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 962, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        title = "맥타마톤 설정"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
        backgroundColor = NSColor(model.theme.backdrop)
        contentView = NSHostingView(rootView: SettingsView(model: model)
            .frame(minWidth: 840, minHeight: 620))
    }
}

private enum Palette {
    static let ink = Color(red: 0.09, green: 0.12, blue: 0.18)
    static let muted = Color(red: 0.35, green: 0.39, blue: 0.47)
    static let blue = Color(red: 0.32, green: 0.50, blue: 0.93)
    static let line = Color(red: 0.68, green: 0.72, blue: 0.79)
}

struct FloatingWidgetView: View {
    @ObservedObject var model: InstrumentModel
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        ZStack {
            widgetBackdrop
                .offset(y: 42)

            WidgetArtView(theme: model.theme, level: model.visualMouthLevel)
            .frame(width: 252, height: 372)
            .accessibilityLabel("\(model.theme.title), 입 열림 \(model.visualMouthLevel + 1)단계")

            VStack {
                HStack {
                    circleButton(model.mouthMotionEnabled ? "mouth.fill" : "mouth",
                                 label: model.mouthMotionEnabled ? "입 움직임 끄기" : "입 움직임 켜기",
                                 action: { model.mouthMotionEnabled.toggle() })
                    Spacer()
                    circleButton("xmark", label: "앱 종료", action: quit)
                }
                Spacer()
                HStack(spacing: 8) {
                    circleButton(model.isPlaying ? "stop.fill" : "play.fill",
                                 label: model.isPlaying ? "연주 멈추기" : "연주 시작",
                                 action: model.togglePlay)
                        .disabled(!model.safeToPlay && !model.isPlaying)
                        .opacity(model.safeToPlay || model.isPlaying ? 1 : 0.5)

                    HStack(spacing: 8) {
                        Text(model.noteName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<5) { index in
                                Capsule()
                                    .fill(index <= model.pitchLevel ? model.theme.accent : Palette.line)
                                    .frame(width: 4, height: CGFloat([10, 17, 13, 21, 15][index]))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .modifier(WidgetLiquidGlassCapsule())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("현재 음 \(model.noteName)")

                    circleButton("gearshape", label: "설정 열기", action: openSettings)
                }
            }
            .padding(.horizontal, 21)
            .padding(.top, 27)
            .padding(.bottom, 18)
        }
        .frame(width: 320, height: 476)
    }

    private var widgetBackdrop: some View {
        Group {
            if #available(macOS 26.0, *) {
                Color.clear
                    .frame(width: 302, height: 302)
                    .glassEffect(.regular, in: Circle())
                    .opacity(0.5)
            } else {
                Circle()
                    .fill(model.theme.backdrop.opacity(0.44))
                    .frame(width: 302, height: 302)
            }
        }
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: Palette.ink.opacity(0.35), radius: 2, y: 1)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(WidgetLiquidGlass())
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct WidgetLiquidGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
        }
    }
}

private struct WidgetLiquidGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

private struct WidgetArtView: NSViewRepresentable {
    let theme: InstrumentTheme
    let level: Int

    func makeNSView(context: Context) -> ArtDragView {
        let view = ArtDragView()
        view.setArt(theme: theme, level: level)
        return view
    }

    func updateNSView(_ nsView: ArtDragView, context: Context) {
        nsView.setArt(theme: theme, level: level)
    }

    final class ArtDragView: NSView {
        private let artLayer = CALayer()
        private var currentLevel = -1
        private var currentTheme: InstrumentTheme?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.isOpaque = false
            layer?.masksToBounds = true
            artLayer.contentsGravity = .resizeAspect
            artLayer.magnificationFilter = .linear
            layer?.addSublayer(artLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override var isOpaque: Bool { false }

        override func layout() {
            super.layout()
            artLayer.frame = CGRect(x: (bounds.width - 372) / 2, y: (bounds.height - 372) / 2,
                                    width: 372, height: 372)
        }

        func setArt(theme: InstrumentTheme, level: Int) {
            guard level != currentLevel || theme != currentTheme else { return }
            currentLevel = level
            currentTheme = theme
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            artLayer.contents = Art.widgetCGImage(theme: theme, level: level)
            CATransaction.commit()
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: InstrumentModel

    var body: some View {
        HStack(spacing: 18) {
            controlPanel
                .frame(width: 246)
            stage
        }
        .padding(20)
        .padding(.top, SettingsWindow.trafficLightInset)
        .background(model.theme.backdrop.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .foregroundStyle(Palette.ink)
    }

    private var controlPanel: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Otamatone")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .tracking(-1.5)
                Text("MAC INSTRUMENT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 2)
                Text("화면을 움직여 연주하세요")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 17)

                themePicker
                    .padding(.top, 22)

                Spacer(minLength: 16)

                Button(action: model.togglePlay) {
                    HStack(spacing: 14) {
                        Image(systemName: model.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 54, height: 54)
                            .background(model.safeToPlay ? Palette.ink : Palette.line,
                                        in: RoundedRectangle(cornerRadius: 17))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.isPlaying ? "소리 멈추기" : "연주 시작")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text(model.safeToPlay ? "화면을 천천히 움직여요" : "화면을 열어주세요")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!model.safeToPlay && !model.isPlaying)
                .accessibilityHint("소리를 켠 뒤 화면 각도를 움직이면 음높이가 바뀝니다")

                Rectangle().fill(Palette.line.opacity(0.55)).frame(height: 1).padding(.vertical, 25)

                Text("입력 방식")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                HStack(spacing: 6) {
                    ForEach(InputMode.allCases) { mode in
                        Button { model.inputMode = mode } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(model.inputMode == mode ? .white : Palette.ink)
                                .background(model.inputMode == mode ? Palette.ink : .white.opacity(0.55),
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)

                if model.inputMode == .manual {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("음높이")
                            .font(.system(size: 12, weight: .semibold))
                        ValueTrack(value: $model.manualAngle, range: 55...145, label: "음높이", accent: model.theme.accent)
                    }
                    .padding(.top, 22)
                } else {
                    Text(model.lidAngle < 25 && model.sensorConnected
                         ? "화면을 조금 더 열면 연주할 수 있어요."
                         : model.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("입 음색")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(Int(model.mouth * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Palette.muted)
                    }
                    ValueTrack(value: $model.mouth, range: 0.1...1, label: "입 음색", accent: model.theme.accent)
                }
                .padding(.top, 22)

                Spacer(minLength: 28)

                HStack(spacing: 7) {
                    Circle()
                        .fill(model.sensorConnected ? model.theme.accent : Palette.muted)
                        .frame(width: 8, height: 8)
                    Text(model.sensorConnected ? "센서 연결됨" : "수동 모드 사용 가능")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
                if let error = model.audioError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(23)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.40), in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26)
            .stroke(.white.opacity(0.75), lineWidth: 1))
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("테마", selection: $model.theme) {
                ForEach(InstrumentTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .pickerStyle(.menu)

            HStack(spacing: 4) {
                ForEach(InstrumentTheme.allCases) { theme in
                    Button { model.theme = theme } label: {
                        Image(nsImage: Art.previewImage(theme: theme))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 29, height: 48)
                            .background(theme.backdrop.opacity(0.8), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(model.theme == theme ? theme.accent : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .help(theme.title)
                    .accessibilityLabel(theme.title)
                    .accessibilityAddTraits(model.theme == theme ? [.isSelected] : [])
                }
            }
        }
    }

    private var stage: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                model.theme.backdrop
                if let background = Art.backgroundImage(theme: model.theme) {
                    Image(nsImage: background)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .saturation(0.65)
                        .opacity(model.theme.backgroundOpacity)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                    let artSide = min(geometry.size.width, geometry.size.height)
                    Ellipse()
                        .fill(.black.opacity(0.08))
                        .frame(width: artSide * 0.28, height: artSide * 0.022)
                        .blur(radius: 8)
                        .position(x: geometry.size.width / 2 - artSide * 0.015,
                                  y: (geometry.size.height - artSide) / 2 + artSide * 0.958)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
                ForEach(0..<5) { level in
                    Image(nsImage: Art.stageImage(theme: model.theme, level: level))
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 16)
                        .opacity(model.theme == .classic && model.visualMouthLevel == level ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .animation(.easeInOut(duration: 0.14), value: model.visualMouthLevel)
                ForEach(0..<5) { level in
                    Image(nsImage: Art.stageImage(theme: model.theme, level: level))
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(model.visualMouthLevel == level ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .animation(.easeInOut(duration: 0.14), value: model.visualMouthLevel)

                VStack {
                    HStack(alignment: .top) {
                        Text("LIVE  ·  OTAMATONE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(Palette.ink.opacity(0.75))
                            .padding(12)
                            .background(.white.opacity(0.45), in: Capsule())
                        Spacer()
                        noteCard
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("화면 각도  \(Int(model.activeAngle.rounded()))°")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.65), in: Capsule())
                    }
                }
                .padding(20)

                if model.isPlaying && model.safeToPlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(model.theme.accent.opacity(0.9))
                        .position(x: geometry.size.width * 0.22, y: geometry.size.height * 0.53)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26)
                .stroke(.white.opacity(0.76), lineWidth: 1))
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(model.noteName)
                .font(.system(size: 43, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<5) { index in
                    Capsule()
                        .fill(index <= model.pitchLevel ? model.theme.accent : .white.opacity(0.75))
                        .frame(width: 6, height: CGFloat([19, 31, 24, 37, 29][index]))
                }
            }
            Text(model.isPlaying && model.safeToPlay ? "SINGING…" : "READY")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Palette.muted)
            Text("\(Int(model.frequency.rounded())) Hz")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.muted)
        }
        .padding(18)
        .frame(width: 147, alignment: .leading)
        .background(.white.opacity(0.50), in: RoundedRectangle(cornerRadius: 23))
        .overlay(RoundedRectangle(cornerRadius: 23)
            .stroke(.white.opacity(0.78), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct ValueTrack: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    var accent: Color = Palette.blue

    var body: some View {
        GeometryReader { geometry in
            let usable = max(1, geometry.size.width - 18)
            let progress = min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line.opacity(0.65)).frame(height: 7)
                Capsule().fill(accent)
                    .frame(width: max(8, 9 + usable * progress), height: 7)
                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(accent, lineWidth: 2))
                    .offset(x: usable * progress)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                let next = min(max((gesture.location.x - 9) / usable, 0), 1)
                value = range.lowerBound + next * (range.upperBound - range.lowerBound)
            })
        }
        .frame(height: 22)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value.rounded()))")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }
}
