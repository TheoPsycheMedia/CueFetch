import AppKit
import CueFetchCore
import SwiftUI

struct OrbitOutputSummary: Equatable {
    let title: String
    let detail: String
    let sizeLabel: String
    let systemImage: String

    static func make(
        preset: OutputPreset,
        selectedFormat: MediaFormat?
    ) -> OrbitOutputSummary {
        switch preset {
        case .mp4FullHD:
            return OrbitOutputSummary(
                title: "1080p MP4",
                detail: "Video + audio · works in most apps",
                sizeLabel: "Calculated during download",
                systemImage: "play.rectangle.fill"
            )
        case .audioOnly:
            return OrbitOutputSummary(
                title: "M4A Audio",
                detail: "Audio only · works in Music",
                sizeLabel: "Calculated during download",
                systemImage: "waveform"
            )
        case .bestVideo, .custom:
            guard let selectedFormat else {
                return OrbitOutputSummary(
                    title: preset == .bestVideo ? "Best available" : "Choose a format",
                    detail: "Open Other formats to choose an output",
                    sizeLabel: "—",
                    systemImage: "slider.horizontal.3"
                )
            }

            let container = selectedFormat.container.uppercased()
            return OrbitOutputSummary(
                title: "\(selectedFormat.quality) \(container)",
                detail: selectedFormat.compatibility,
                sizeLabel: normalizedSize(selectedFormat.estimatedSize),
                systemImage: selectedFormat.isAudioOnly ? "waveform" : "play.rectangle.fill"
            )
        }
    }

    private static func normalizedSize(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "-" ? "Calculated during download" : trimmed
    }
}

struct OrbitQualityChoice: Identifiable, Equatable {
    enum Selection: Equatable {
        case preset(OutputPreset)
        case format(UUID)
        case unavailable
    }

    let id: String
    let label: String
    let detail: String
    let angle: Double
    let selection: Selection

    var isEnabled: Bool {
        selection != .unavailable
    }
}

enum OrbitQualityChoiceBuilder {
    static func choices(for candidate: DownloadCandidate?) -> [OrbitQualityChoice] {
        guard let candidate else {
            return placeholders
        }

        let videoFormats = candidate.formats.filter { !$0.isAudioOnly }
        guard !videoFormats.isEmpty else {
            let hasAudio = candidate.formats.contains(where: \.isAudioOnly)
            return [
                unavailable(id: "video-low", label: "Video", angle: -90),
                OrbitQualityChoice(
                    id: "audio",
                    label: "Audio",
                    detail: hasAudio ? "Available" : "Unavailable",
                    angle: 0,
                    selection: hasAudio ? .preset(.audioOnly) : .unavailable
                ),
                unavailable(id: "video-high", label: "Higher", angle: 90)
            ]
        }

        let low = videoFormats
            .filter { ($0.pixelHeight ?? 0) > 0 && ($0.pixelHeight ?? 0) <= 720 }
            .max { ($0.pixelHeight ?? 0) < ($1.pixelHeight ?? 0) }
        let high = videoFormats
            .filter { ($0.pixelHeight ?? 0) > 1080 }
            .max { ($0.pixelHeight ?? 0) < ($1.pixelHeight ?? 0) }

        return [
            low.map {
                OrbitQualityChoice(
                    id: "format-\($0.id)",
                    label: displayQuality(for: $0),
                    detail: "Smaller",
                    angle: -90,
                    selection: .format($0.id)
                )
            } ?? unavailable(id: "720p", label: "720p", angle: -90),
            OrbitQualityChoice(
                id: "compatible-1080p",
                label: "1080p",
                detail: "Recommended",
                angle: 0,
                selection: .preset(.mp4FullHD)
            ),
            high.map {
                OrbitQualityChoice(
                    id: "format-\($0.id)",
                    label: displayQuality(for: $0),
                    detail: "Highest",
                    angle: 90,
                    selection: .format($0.id)
                )
            } ?? unavailable(id: "4k", label: "4K", angle: 90)
        ]
    }

    private static let placeholders = [
        unavailable(id: "720p", label: "720p", angle: -90),
        unavailable(id: "1080p", label: "1080p", angle: 0),
        unavailable(id: "4k", label: "4K", angle: 90)
    ]

    private static func unavailable(id: String, label: String, angle: Double) -> OrbitQualityChoice {
        OrbitQualityChoice(
            id: id,
            label: label,
            detail: "Unavailable",
            angle: angle,
            selection: .unavailable
        )
    }

    private static func displayQuality(for format: MediaFormat) -> String {
        guard let height = format.pixelHeight else { return format.quality }
        return height >= 2160 ? "4K" : format.quality
    }
}

struct LiquidOrbitView: View {
    @ObservedObject var store: DownloadStore
    @State private var isShowingAdvanced = false
    @State private var isShowingHistory = false

    var body: some View {
        ZStack {
            OrbitBackdrop(candidate: store.candidate)

            CueGlassContainer(spacing: 26) {
                VStack(spacing: 14) {
                    header
                    LinkIntakeBar(store: store)

                    OrbitMainStage(
                        store: store,
                        showAdvanced: { isShowingAdvanced = true }
                    )

                    BottomTransferRail(store: store)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingAdvanced) {
            AdvancedDownloadSheet(store: store, isPresented: $isShowingAdvanced)
        }
        .animation(.easeInOut(duration: 0.24), value: store.selectedPreset)
        .animation(.easeInOut(duration: 0.24), value: store.selectedFormatID)
        .animation(.easeInOut(duration: 0.24), value: store.candidate?.id)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)

            Text("CueFetch")
                .font(.system(size: 20, weight: .semibold))

            Spacer()

            Button {
                isShowingHistory.toggle()
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .padding(.horizontal, 4)
            }
            .cueGlassButtonStyle()
            .popover(isPresented: $isShowingHistory, arrowEdge: .top) {
                OrbitHistoryPopover(store: store, isPresented: $isShowingHistory)
            }

            Button {
                store.refreshToolStatus()
                store.isShowingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .padding(.horizontal, 4)
            }
            .cueGlassButtonStyle()
        }
        .padding(.leading, 74)
        .padding(.top, 10)
        .frame(height: 54)
    }
}

private struct OrbitBackdrop: View {
    let candidate: DownloadCandidate?

    var body: some View {
        ZStack {
            CueFetchTheme.orbitBackground

            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.14, blue: 0.24),
                    Color(red: 0.02, green: 0.04, blue: 0.07),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let urlString = candidate?.thumbnailURL,
               let url = URL(string: urlString) {
                GeometryReader { proxy in
                    AsyncImage(url: url) { phase in
                        if case let .success(image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(1.16)
                    .blur(radius: 34)
                    .opacity(0.40)
                    .clipped()
                }
            }

            RadialGradient(
                colors: [CueFetchTheme.blue.opacity(0.20), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 520
            )

            LinearGradient(
                colors: [.black.opacity(0.12), .black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct LinkIntakeBar: View {
    @ObservedObject var store: DownloadStore

    private var controlState: DownloadInputControlState {
        DownloadInputControlState(
            hasAnalyzableInput: store.canAnalyze,
            isAnalyzing: store.isAnalyzing,
            isDownloading: store.isDownloading
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))

                TextField(
                    "Paste a media link",
                    text: Binding(
                        get: { store.inputURL },
                        set: { store.setInputURL($0) }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .frame(minWidth: 0, maxWidth: .infinity)
                .layoutPriority(1)
                .disabled(!controlState.isURLInputEnabled)
                .onSubmit {
                    guard controlState.isAnalyzeEnabled else { return }
                    store.analyzeLink()
                }

                analyzeButton
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(height: 58)
            .cueGlassSurface(radius: 29)

            if let warning = store.pendingIntakeWarning {
                OrbitIntakeWarning(store: store, warning: warning)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var analyzeButton: some View {
        Button {
            store.analyzeLink()
        } label: {
            HStack(spacing: 8) {
                if store.isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "sparkle.magnifyingglass")
                }
                Text(store.isAnalyzing ? "Analyzing" : "Analyze")
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(minWidth: 116, minHeight: 32)
        }
        .cueProminentGlassButtonStyle()
        .disabled(!controlState.isAnalyzeEnabled)
    }
}

private struct OrbitIntakeWarning: View {
    @ObservedObject var store: DownloadStore
    let warning: URLIntakeResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: warning.kind == .multipleLinks ? "link.badge.plus" : "rectangle.stack.badge.play")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)
            }

            Spacer()

            if warning.kind != .playlist || warning.canAnalyzeSingleVideo {
                Button(primaryActionTitle) {
                    store.analyzePrimaryIntakeURL()
                }
                .cueProminentGlassButtonStyle()
            }

            Button("Cancel") {
                store.clearIntakeWarning()
            }
            .cueGlassButtonStyle()
        }
        .padding(12)
        .cueGlassSurface(radius: 16, tint: .orange.opacity(0.12))
    }

    private var title: String {
        warning.kind == .multipleLinks ? "\(warning.urlCount) links pasted" : "Playlist detected"
    }

    private var detail: String {
        switch warning.kind {
        case .multipleLinks:
            "CueFetch works with one link at a time."
        case .playlist:
            warning.canAnalyzeSingleVideo
                ? "Only the direct video will be analyzed."
                : "Paste a direct media link instead of a playlist."
        case .single, .empty, .invalid:
            "Review the link before continuing."
        }
    }

    private var primaryActionTitle: String {
        warning.kind == .multipleLinks ? "Analyze First" : "Video Only"
    }
}

private struct OrbitMainStage: View {
    @ObservedObject var store: DownloadStore
    let showAdvanced: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let leftWidth = max(440, proxy.size.width * 0.54)

            ZStack {
                connector(in: proxy.size)

                HStack(spacing: 20) {
                    OrbitDialView(store: store)
                        .frame(width: leftWidth)

                    OrbitDetailsPanel(store: store, showAdvanced: showAdvanced)
                        .frame(maxWidth: 440)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minHeight: 390)
    }

    private func connector(in size: CGSize) -> some View {
        let start = CGPoint(x: size.width * 0.47, y: size.height * 0.54)
        let end = CGPoint(x: size.width * 0.62, y: size.height * 0.54)

        return ZStack {
            Path { path in
                path.move(to: start)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: size.width * 0.52, y: size.height * 0.54),
                    control2: CGPoint(x: size.width * 0.57, y: size.height * 0.54)
                )
            }
            .stroke(CueFetchTheme.blue.opacity(0.32), lineWidth: 12)
            .blur(radius: 10)

            Path { path in
                path.move(to: start)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: size.width * 0.52, y: size.height * 0.54),
                    control2: CGPoint(x: size.width * 0.57, y: size.height * 0.54)
                )
            }
            .stroke(
                LinearGradient(
                    colors: [CueFetchTheme.blue, .cyan.opacity(0.70)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
        }
        .allowsHitTesting(false)
    }
}

private struct OrbitDialView: View {
    @ObservedObject var store: DownloadStore

    private var choices: [OrbitQualityChoice] {
        OrbitQualityChoiceBuilder.choices(for: store.candidate)
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width * 0.70, proxy.size.height * 0.82)
            let center = CGPoint(x: proxy.size.width * 0.43, y: proxy.size.height * 0.52)
            let nodeRadius = diameter * 0.50

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.11), lineWidth: 22)
                    .frame(width: diameter, height: diameter)
                    .position(center)

                Circle()
                    .trim(from: 0.035, to: 0.965)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                CueFetchTheme.blue.opacity(0.86),
                                Color.white.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter, height: diameter)
                    .shadow(color: CueFetchTheme.blue.opacity(0.32), radius: 12)
                    .position(center)

                if store.isDownloading {
                    Circle()
                        .trim(from: 0, to: max(store.downloadProgress, 0.02))
                        .stroke(
                            Color.cyan,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: diameter, height: diameter)
                        .shadow(color: .cyan.opacity(0.7), radius: 10)
                        .position(center)
                }

                artwork(diameter: diameter * 0.69)
                    .position(center)

                ForEach(choices) { choice in
                    qualityNode(choice, center: center, radius: nodeRadius)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Output quality orbit")
    }

    @ViewBuilder
    private func artwork(diameter: CGFloat) -> some View {
        if let candidate = store.candidate {
            MediaThumbnailView(name: candidate.thumbnailName, urlString: candidate.thumbnailURL)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.42), radius: 22, y: 10)
        } else {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.30))
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.60))
            }
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
        }
    }

    private func qualityNode(
        _ choice: OrbitQualityChoice,
        center: CGPoint,
        radius: CGFloat
    ) -> some View {
        let radians = choice.angle * .pi / 180
        let point = CGPoint(
            x: center.x + CGFloat(cos(radians)) * radius,
            y: center.y + CGFloat(sin(radians)) * radius
        )
        let labelPoint = CGPoint(x: point.x + 94, y: point.y)
        let selected = isSelected(choice)

        return ZStack {
            Button {
                select(choice)
            } label: {
                ZStack {
                    Circle()
                        .fill(selected ? CueFetchTheme.blue.opacity(0.94) : Color.black.opacity(0.22))
                    if selected {
                        Circle()
                            .stroke(Color.white.opacity(0.82), lineWidth: 2)
                            .padding(6)
                    }
                }
                .frame(width: selected ? 52 : 40, height: selected ? 52 : 40)
                .cueGlassCircle(
                    tint: selected ? CueFetchTheme.blue.opacity(0.66) : nil,
                    interactive: choice.isEnabled
                )
            }
            .buttonStyle(.plain)
            .disabled(!choice.isEnabled || store.isDownloading)
            .position(point)

            VStack(alignment: .leading, spacing: 2) {
                Text(choice.label)
                    .font(.system(size: selected ? 18 : 15, weight: selected ? .semibold : .medium))
                if choice.detail != "Unavailable" {
                    Text(choice.detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(selected ? CueFetchTheme.blue : .white.opacity(0.46))
                }
            }
            .frame(width: 132, alignment: .leading)
            .opacity(choice.isEnabled ? 1 : 0.48)
            .position(labelPoint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(choice.label), \(choice.detail)\(selected ? ", selected" : "")")
    }

    private func isSelected(_ choice: OrbitQualityChoice) -> Bool {
        switch choice.selection {
        case let .preset(preset):
            store.selectedPreset == preset
        case let .format(id):
            store.selectedFormatID == id
        case .unavailable:
            false
        }
    }

    private func select(_ choice: OrbitQualityChoice) {
        switch choice.selection {
        case let .preset(preset):
            store.selectPreset(preset)
        case let .format(id):
            store.selectFormat(id: id)
        case .unavailable:
            break
        }
    }
}

private struct OrbitDetailsPanel: View {
    @ObservedObject var store: DownloadStore
    let showAdvanced: () -> Void

    private var summary: OrbitOutputSummary {
        OrbitOutputSummary.make(
            preset: store.selectedPreset,
            selectedFormat: store.selectedFormat
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.candidate?.title ?? "Paste a media link")
                    .font(.system(size: 21, weight: .semibold))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(store.candidate?.domain ?? "CueFetch will inspect the source")
                    if let duration = store.candidate?.duration, !duration.isEmpty {
                        Text("·")
                        Text(duration)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.62))
            }

            Divider()
                .overlay(Color.white.opacity(0.10))
                .padding(.vertical, 18)

            HStack(spacing: 10) {
                Image(systemName: summary.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(CueFetchTheme.blue)
                Text(store.candidate == nil ? "Ready when you are" : summary.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CueFetchTheme.blue)
            }

            Text(store.candidate == nil ? "Paste a supported link to see real output choices." : summary.detail)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.68))
                .padding(.top, 6)

            HStack {
                Text("Estimated size")
                Spacer()
                Text(store.candidate == nil ? "—" : summary.sizeLabel)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.58))
            .padding(.top, 18)

            Divider()
                .overlay(Color.white.opacity(0.10))
                .padding(.vertical, 16)

            Button {
                store.chooseDestination()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .foregroundStyle(CueFetchTheme.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.destination)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("Save here")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    Text("Change")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.isDownloading)

            Label("Processed on this Mac · No CueFetch cloud", systemImage: "lock")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.56))
                .padding(.top, 16)

            if store.candidate?.accessState == .cookiesRequired && !store.useBrowserCookies {
                Button {
                    store.addCookies()
                } label: {
                    Label("Use Safari Cookies for This Download", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .cueGlassButtonStyle()
                .padding(.top, 14)
            }

            if !store.lastErrorMessage.isEmpty {
                Label(store.lastErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .padding(.top, 12)
            }

            Spacer(minLength: 16)

            downloadButton

            Button("Other formats") {
                showAdvanced()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(CueFetchTheme.blue)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .disabled(store.candidate == nil)

            if store.isDownloading {
                ProgressView(value: store.downloadProgress)
                    .tint(.cyan)
                    .padding(.top, 12)
                Text("\(Int(store.downloadProgress * 100))% · \(store.statusMessage)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: 470, alignment: .topLeading)
        .cueGlassSurface(radius: 32)
    }

    @ViewBuilder
    private var downloadButton: some View {
        Button {
            if store.isDownloading {
                store.cancelDownload()
            } else {
                store.startDownload()
            }
        } label: {
            Label(
                store.isDownloading ? "Cancel Download" : "Download to Mac",
                systemImage: store.isDownloading ? "xmark" : "arrow.down.to.line"
            )
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .cueProminentGlassButtonStyle()
        .disabled(!store.canDownload && !store.isDownloading)
    }
}

private struct BottomTransferRail: View {
    @ObservedObject var store: DownloadStore

    private var summary: OrbitOutputSummary {
        OrbitOutputSummary.make(
            preset: store.selectedPreset,
            selectedFormat: store.selectedFormat
        )
    }

    var body: some View {
        HStack(spacing: 14) {
            if let candidate = store.candidate {
                MediaThumbnailView(name: candidate.thumbnailName, urlString: candidate.thumbnailURL)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 420, alignment: .leading)
                    Text("\(summary.title) · \(summary.sizeLabel)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }
            } else {
                Image(systemName: store.toolStatus.isYTDLPInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(store.toolStatus.isYTDLPInstalled ? .green : .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.toolStatus.isYTDLPInstalled ? "Ready for a media link" : "Setup required")
                        .font(.system(size: 13, weight: .medium))
                    Text(store.statusMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.54))
                }
            }

            Spacer()

            if !store.lastDownloadedPath.isEmpty {
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
                Button("Show in Finder") {
                    store.revealLastDownload()
                }
                .cueGlassButtonStyle()
            } else {
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 110, height: 1)
                        .overlay {
                            Rectangle()
                                .fill(CueFetchTheme.blue.opacity(store.candidate == nil ? 0.2 : 0.85))
                                .frame(width: store.candidate == nil ? 0 : 70, height: 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 66)
        .cueGlassSurface(radius: 22)
    }
}

private struct OrbitHistoryPopover: View {
    @ObservedObject var store: DownloadStore
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Session History")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Clear") {
                    store.clearRecentLinks()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(store.recentLinks.isEmpty)
            }
            .padding(16)

            Divider()

            if store.recentLinks.isEmpty {
                ContentUnavailableView(
                    "No Recent Links",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Analyzed links stay here for this app session.")
                )
                .frame(height: 180)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.recentLinks) { link in
                            Button {
                                store.selectRecent(link)
                                isPresented = false
                            } label: {
                                HStack(spacing: 12) {
                                    ThumbnailView(name: link.thumbnailName)
                                        .frame(width: 58, height: 36)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(link.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                        Text("\(link.domain) · \(link.dateLabel)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if link.id != store.recentLinks.last?.id {
                                Divider()
                                    .padding(.leading, 84)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 380)
        .background(CueFetchTheme.page)
    }
}

private struct AdvancedDownloadSheet: View {
    @ObservedObject var store: DownloadStore
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Download Details")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Profiles, captions, exact formats, compatibility, and recovery tools")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider()

            PreflightPane(store: store)
        }
        .frame(width: 880, height: 680)
        .background(CueFetchTheme.page)
        .preferredColorScheme(.dark)
    }
}
