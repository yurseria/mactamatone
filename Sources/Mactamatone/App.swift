import AppKit
import Combine
import QuartzCore
import SwiftUI

enum InputMode: String, CaseIterable, Identifiable {
    case lid, manual
    var id: Self { self }
    func title(in language: AppLanguage) -> String {
        language.text(self == .lid ? .lidInput : .manualInput)
    }
}

final class InstrumentModel: ObservableObject {
    static let pitchAngleRange: ClosedRange<Double> = 25...130
    private static var pitchAngleSpan: Double { pitchAngleRange.upperBound - pitchAngleRange.lowerBound }

    @Published var theme: InstrumentTheme {
        didSet { preferences.set(theme.rawValue, forKey: InstrumentTheme.preferenceKey) }
    }
    @Published var language: AppLanguage {
        didSet { preferences.set(language.rawValue, forKey: AppLanguage.preferenceKey) }
    }
    private let preferences: UserDefaults
    @Published var inputMode: InputMode = .lid { didSet { updatePitchLevel(); updateSound() } }
    @Published var lidAngle = 120.0 { didSet { updatePitchLevel(); updateSound() } }
    @Published var manualAngle = 100.0 { didSet { updatePitchLevel(); updateSound() } }
    @Published var mouth = 0.5 { didSet { updateSound() } }
    @Published private(set) var pitchLevel = 3
    @Published var isPlaying = false { didSet { updateSound() } }
    @Published var sensorConnected = false
    @Published var sensorStatus: SensorStatus = .checking
    @Published var audioErrorDetail: String?

    var statusMessage: String { sensorStatus.text(in: language) }
    var audioError: String? { audioErrorDetail.map { language.format(.audioStartFailed, $0) } }

    let updater = AppUpdater()
    let audioActivity = AudioActivity()
    private let sensor = LidSensor()
    private let synth = OtamatoneSynth()
    private var hasStarted = false

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        self.theme = InstrumentTheme.saved(in: preferences)
        self.language = AppLanguage.saved(in: preferences)
        sensor.onAngle = { [weak self] value in
            self?.lidAngle = value
        }
        sensor.onStatus = { [weak self] connected, status in
            guard let self else { return }
            self.sensorConnected = connected
            self.sensorStatus = status
            if !connected && self.inputMode == .lid { self.inputMode = .manual }
            self.updateSound()
        }
        updatePitchLevel()
    }

    var activeAngle: Double { inputMode == .lid ? lidAngle : manualAngle }
    var safeToPlay: Bool { inputMode == .manual || (sensorConnected && lidAngle >= Self.pitchAngleRange.lowerBound) }
    var normalizedPitch: Double { min(max((activeAngle - Self.pitchAngleRange.lowerBound) / Self.pitchAngleSpan, 0), 1) }
    var visualMouthLevel: Int { pitchLevel }
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
        audioActivity.start { [weak self] in self?.synth.outputSample ?? .silent }
    }

    func togglePlay() {
        if isPlaying { isPlaying = false; return }
        guard safeToPlay else { return }
        do {
            try synth.start()
            audioErrorDetail = nil
            isPlaying = true
        } catch {
            audioErrorDetail = error.localizedDescription
        }
    }

    func stop() {
        isPlaying = false
        synth.stop()
        audioActivity.stop()
        sensor.stop()
        hasStarted = false
    }

    private func updatePitchLevel() {
        // Keep the current image until the angle is safely past a level boundary.
        // This prevents sensor noise from switching two images every 33 ms.
        let margin = 2.0 / Self.pitchAngleSpan
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
    private var languageSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
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
        widget.title = model.language.text(.appTitle)
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
        languageSubscription = model.$language.sink { [weak widget] language in
            widget?.title = language.text(.appTitle)
        }
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
    private var languageSubscription: AnyCancellable?

    init(model: InstrumentModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 962, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        title = model.language.text(.settingsTitle)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
        // The settings palette is light, so native controls must use matching colors.
        appearance = NSAppearance(named: .aqua)
        backgroundColor = NSColor(model.theme.backdrop)
        contentView = NSHostingView(rootView: SettingsView(model: model)
            .frame(minWidth: 840, minHeight: 620))
        languageSubscription = model.$language.sink { [weak self] language in
            self?.title = language.text(.settingsTitle)
        }
    }
}

private enum Palette {
    static let ink = Color(red: 0.09, green: 0.12, blue: 0.18)
    static let muted = Color(red: 0.35, green: 0.39, blue: 0.47)
    static let blue = Color(red: 0.32, green: 0.50, blue: 0.93)
    static let line = Color(red: 0.68, green: 0.72, blue: 0.79)
}

// Select the property wrapper explicitly when an SDK also exports a State macro.
private typealias WidgetState<Value> = SwiftUI.State<Value>

struct FloatingWidgetView: View {
    @ObservedObject var model: InstrumentModel
    let openSettings: () -> Void
    let quit: () -> Void
    @WidgetState private var isLanguagePickerPresented = false

    var body: some View {
        ZStack {
            widgetBackdrop
                .offset(y: 42)

            AudioReactiveGlow(theme: model.theme, activity: model.audioActivity)
                .offset(y: 42)

            WidgetArtView(theme: model.theme, level: model.visualMouthLevel)
            .frame(width: 252, height: 372)
            .accessibilityLabel(model.language.format(.artDescription, model.theme.title(in: model.language), model.visualMouthLevel + 1))

            VStack {
                HStack {
                    languageButton
                    Spacer()
                    circleButton("xmark", label: model.language.text(.quit), action: quit)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: model.togglePlay) {
                        MusicPlaybackIcon(isPlaying: model.isPlaying && model.safeToPlay)
                            .foregroundStyle(.white)
                            .shadow(color: Palette.ink.opacity(0.35), radius: 2, y: 1)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .modifier(WidgetLiquidGlass())
                    .accessibilityLabel(model.language.text(model.isPlaying ? .stopPlaying : .startPlaying))
                    .help(model.language.text(model.isPlaying ? .stopPlaying : .startPlaying))
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
                    .accessibilityLabel(model.language.format(.currentNote, model.noteName))

                    circleButton("gearshape", label: model.language.text(.openSettings), action: openSettings)
                }
            }
            .padding(.horizontal, 21)
            .padding(.top, 27)
            .padding(.bottom, 18)
        }
        .frame(width: 320, height: 476)
        .environment(\.locale, model.language.locale)
    }

    private var languageButton: some View {
        circleButton("globe", label: model.language.text(.language)) {
            isLanguagePickerPresented.toggle()
        }
        .accessibilityValue(model.language.title)
        .popover(isPresented: $isLanguagePickerPresented) {
            VStack(spacing: 4) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        model.language = language
                        isLanguagePickerPresented = false
                    } label: {
                        HStack {
                            Text(language.title)
                            Spacer()
                            Image(systemName: "checkmark")
                                .opacity(model.language == language ? 1 : 0)
                                .accessibilityHidden(true)
                        }
                        .padding(10)
                        .contentShape(Rectangle())
                        .background(model.language == language ? Color.accentColor.opacity(0.15) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.title)
                    .accessibilityAddTraits(model.language == language ? [.isSelected] : [])
                }
            }
            .padding(10)
            .frame(width: 170)
        }
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

/// A beamed note stays recognizable in both sound states; the slash means muted.
struct MusicPlaybackIcon: View {
    let isPlaying: Bool

    var body: some View {
        Text("♫")
            .font(.system(size: 26, weight: .medium))
            .overlay {
                if !isPlaying {
                    Path { path in
                        path.move(to: CGPoint(x: 2, y: 29))
                        path.addLine(to: CGPoint(x: 25, y: 3))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 27, height: 32)
                }
            }
            .accessibilityHidden(true)
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

/// A native selection menu with a trailing value and no enclosing box.
private struct SettingsSelectionRow<Selection: Hashable>: View {
    let title: String
    @Binding var selection: Selection
    let options: [Selection]
    let optionTitle: (Selection) -> String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            Menu {
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(optionTitle(option)).tag(option)
                    }
                }
                .labelsHidden()
            } label: {
                HStack(spacing: 8) {
                    Text(optionTitle(selection))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 23, height: 23)
                        .background(Palette.ink.opacity(0.07), in: Circle())
                }
                .foregroundStyle(Palette.ink)
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(title)
            .accessibilityValue(optionTitle(selection))
        }
        .font(.system(size: 12, weight: .semibold))
        .frame(maxWidth: .infinity)
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
        .environment(\.colorScheme, .light)
        .environment(\.locale, model.language.locale)
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Otamatone")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .tracking(-1.5)
                    Text(model.language.format(.versionLabel, model.updater.current.version, model.updater.current.build))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 3)
                    Text(model.language.text(.instrumentSubtitle))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 2)
                    Text(model.language.text(.playInstruction))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 12)

                    SettingsSelectionRow(
                        title: model.language.text(.language),
                        selection: $model.language,
                        options: AppLanguage.allCases,
                        optionTitle: { $0.title }
                    )
                    .padding(.top, 14)

                    themePicker
                        .padding(.top, 12)

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
                                Text(model.language.text(model.isPlaying ? .stopPlaying : .startPlaying))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Text(model.language.text(!model.safeToPlay ? .openLid : model.inputMode == .manual ? .adjustPitch : .moveLidSlowly))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.safeToPlay && !model.isPlaying)
                    .accessibilityHint(model.language.text(.playHint))

                    Rectangle().fill(Palette.line.opacity(0.55)).frame(height: 1).padding(.vertical, 16)

                    Text(model.language.text(.inputMode))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                    HStack(spacing: 6) {
                        ForEach(InputMode.allCases) { mode in
                            Button { model.inputMode = mode } label: {
                                Text(mode.title(in: model.language))
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
                            Text(model.language.text(.pitch))
                                .font(.system(size: 12, weight: .semibold))
                            ValueTrack(value: $model.manualAngle, range: InstrumentModel.pitchAngleRange, label: model.language.text(.pitch), accent: model.theme.accent)
                        }
                        .padding(.top, 14)
                    } else {
                        Text(model.lidAngle < 25 && model.sensorConnected
                             ? model.language.text(.openLidMore)
                             : model.statusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 18)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(model.language.text(.mouthTimbre))
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("\(Int(model.mouth * 100))%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Palette.muted)
                        }
                        ValueTrack(value: $model.mouth, range: 0.1...1, label: model.language.text(.mouthTimbre), accent: model.theme.accent)
                    }
                    .padding(.top, 14)

                    Spacer(minLength: 12)

                    HStack(spacing: 7) {
                        Circle()
                            .fill(model.sensorConnected ? model.theme.accent : Palette.muted)
                            .frame(width: 8, height: 8)
                        Text(model.language.text(model.sensorConnected ? .sensorConnected : .manualAvailable))
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
            UpdatePanel(updater: model.updater, language: model.language, accent: model.theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(23)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.40), in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26)
            .stroke(.white.opacity(0.75), lineWidth: 1))
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSelectionRow(
                title: model.language.text(.theme),
                selection: $model.theme,
                options: InstrumentTheme.allCases,
                optionTitle: { $0.title(in: model.language) }
            )

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
                    .help(theme.title(in: model.language))
                    .accessibilityLabel(theme.title(in: model.language))
                    .accessibilityAddTraits(model.theme == theme ? [.isSelected] : [])
                }
            }
        }
    }

    private var stage: some View {
        GeometryReader { geometry in
            let artSide = min(geometry.size.width, geometry.size.height)
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
                        .opacity(model.theme == .classic && model.visualMouthLevel == level ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .animation(.easeInOut(duration: 0.14), value: model.visualMouthLevel)

                AudioReactiveGlow(theme: model.theme, activity: model.audioActivity, diameter: artSide * 0.82)
                    .position(x: geometry.size.width / 2,
                              y: (geometry.size.height - artSide) / 2 + artSide * 0.64)

                // Transparent foreground keeps the halo behind the instrument,
                // including Classic's existing background and floor shadow.
                ForEach(0..<5) { level in
                    Image(nsImage: Art.widgetImage(theme: model.theme, level: level))
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
                        Text(model.language.text(.liveBadge))
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
                        Text(model.language.format(.lidAngleValue, Int(model.activeAngle.rounded())))
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
            Text(model.language.text(model.isPlaying && model.safeToPlay ? .singing : .ready))
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
