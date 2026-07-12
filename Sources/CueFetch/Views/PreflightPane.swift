import CueFetchCore
import SwiftUI

struct PreflightPane: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        Group {
            if let candidate = store.candidate {
                LoadedPreflightPane(store: store, candidate: candidate)
            } else {
                EmptyPreflightPane(store: store)
            }
        }
        .background(CueFetchTheme.page)
    }
}

private struct LoadedPreflightPane: View {
    @ObservedObject var store: DownloadStore
    let candidate: DownloadCandidate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HeaderSection(store: store, candidate: candidate)

                ConfidenceSummaryView(store: store)

                Divider()

                ProfileSection(store: store)

                DestinationSection(store: store)

                PresetPicker(store: store)

                FormatTableView(store: store)
                    .layoutPriority(1)

                ActionSection(store: store)

                if !store.lastErrorMessage.isEmpty {
                    ErrorRecoveryPanel(store: store)
                }

                CommandPreviewView(command: store.lastCommandPreview)
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.visible)
    }
}

private struct EmptyPreflightPane: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(CueFetchTheme.blueSoft)
                        .frame(width: 84, height: 84)
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(CueFetchTheme.blue)
                }

                VStack(spacing: 8) {
                    Text("Paste a link to get started")
                        .font(.system(size: 22, weight: .semibold))
                    Text("CueFetch will inspect the URL with yt-dlp and show real formats, metadata, subtitles, and download options here.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 440)
                }

                HStack(spacing: 8) {
                    Image(systemName: store.toolStatus.isYTDLPInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(store.toolStatus.isYTDLPInstalled ? CueFetchTheme.green : CueFetchTheme.orange)
                    Text(store.toolStatus.isYTDLPInstalled ? "yt-dlp is installed" : "yt-dlp was not found")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if !store.lastErrorMessage.isEmpty {
                    ErrorRecoveryPanel(store: store)
                        .frame(maxWidth: 520)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()

            Divider()

            HStack(spacing: 12) {
                Text("Destination")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    Text(store.destination)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.system(size: 13))
                Spacer()
                Button("Change...") {
                    store.chooseDestination()
                }
                .disabled(store.isDownloading)
                Button {
                    store.openDestinationFolder()
                } label: {
                    Label("Open Folder", systemImage: "folder")
                        .labelStyle(.titleAndIcon)
                }
            }
            .padding(.top, 14)
        }
        .padding(22)
    }
}

private struct HeaderSection: View {
    @ObservedObject var store: DownloadStore
    let candidate: DownloadCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ready to download")
                .font(.system(size: 18, weight: .semibold))

            HStack(alignment: .top, spacing: 16) {
                MediaThumbnailView(name: candidate.thumbnailName, urlString: candidate.thumbnailURL)
                    .frame(width: 212, height: 118)
                    .overlay(alignment: .bottomTrailing) {
                        Text(candidate.duration)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .foregroundStyle(.white)
                            .padding(7)
                    }
                    .layoutPriority(1)

                VStack(alignment: .leading, spacing: 10) {
                    Text(candidate.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.92)

                    InfoLine(icon: "play.square.fill", label: candidate.domain, badge: candidate.site)

                    InfoLine(icon: "clock", label: "Duration", value: candidate.duration)
                    InfoLine(icon: "calendar", label: "Published", value: candidate.published)

                    AccessLine(store: store)
                }
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct InfoLine: View {
    let icon: String
    let label: String
    var value: String?
    var badge: SiteKind?

    var body: some View {
        HStack(spacing: 13) {
            if let badge {
                SiteBadge(site: badge)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 22)
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(value == nil ? .primary : .secondary)
                .frame(width: value == nil ? nil : 74, alignment: .leading)

            if let value {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
    }
}

private struct ConfidenceSummaryView: View {
    @ObservedObject var store: DownloadStore

    private var cards: [ConfidenceCardData] {
        [
            accessCard,
            formatCard,
            subtitlesCard,
            toolsCard
        ]
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(cards) { card in
                    ConfidenceCard(card: card)
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ConfidenceCard(card: cards[0])
                    ConfidenceCard(card: cards[1])
                }
                HStack(spacing: 8) {
                    ConfidenceCard(card: cards[2])
                    ConfidenceCard(card: cards[3])
                }
            }
        }
    }

    private var accessCard: ConfidenceCardData {
        let state = store.candidate?.accessState ?? .unsupported
        switch state {
        case .available:
            return ConfidenceCardData(
                title: "Access",
                value: "Ready",
                detail: "yt-dlp can read it",
                systemImage: "checkmark.circle.fill",
                color: CueFetchTheme.green
            )
        case .cookiesRequired:
            return ConfidenceCardData(
                title: "Access",
                value: "Cookies needed",
                detail: "Use Safari cookies",
                systemImage: "exclamationmark.triangle.fill",
                color: CueFetchTheme.orange
            )
        case .unsupported:
            return ConfidenceCardData(
                title: "Access",
                value: "Unsupported",
                detail: "yt-dlp cannot read it",
                systemImage: "xmark.octagon.fill",
                color: .red
            )
        case .drmProtected:
            return ConfidenceCardData(
                title: "Access",
                value: "Blocked",
                detail: "DRM protected",
                systemImage: "lock.fill",
                color: .red
            )
        }
    }

    private var formatCard: ConfidenceCardData {
        guard let plan = store.currentPlan else {
            return ConfidenceCardData(
                title: "Format",
                value: "Choose one",
                detail: "No format selected",
                systemImage: "film.stack",
                color: CueFetchTheme.orange
            )
        }

        let value: String
        let detail: String
        switch plan.effectiveSelection {
        case let .fixedQuickTimeMP4(maximumHeight):
            value = "\(maximumHeight)p MP4"
            detail = "H.264 + AAC"
        case .fixedM4A:
            value = "Audio Only"
            detail = "M4A audio"
        case .selectedFormat:
            guard let format = store.selectedFormat else {
                return ConfidenceCardData(
                    title: "Format",
                    value: "Choose one",
                    detail: "No format selected",
                    systemImage: "film.stack",
                    color: CueFetchTheme.orange
                )
            }
            value = format.quality
            detail = format.isAudioOnly
                ? "\(format.container) audio"
                : "\(format.container) \(format.videoCodec)"
        }

        let isCompatible = plan.compatibility != .requiresConversion

        return ConfidenceCardData(
            title: "Format",
            value: value,
            detail: detail,
            systemImage: isCompatible ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
            color: isCompatible ? CueFetchTheme.green : CueFetchTheme.orange
        )
    }

    private var subtitlesCard: ConfidenceCardData {
        guard let candidate = store.candidate else {
            return ConfidenceCardData(
                title: "Subtitles",
                value: "Unknown",
                detail: "Analyze first",
                systemImage: "captions.bubble",
                color: .secondary
            )
        }

        let hasDetectedSubtitles = !candidate.subtitleLanguages.isEmpty
            || candidate.formats.contains(where: \.subtitles)
        if !hasDetectedSubtitles {
            return ConfidenceCardData(
                title: "Subtitles",
                value: "None found",
                detail: "No captions detected",
                systemImage: "captions.bubble",
                color: .secondary
            )
        }

        return ConfidenceCardData(
            title: "Subtitles",
            value: store.includeSubtitles ? "Included" : "Skipped",
            detail: store.includeSubtitles ? "Captions available" : "Available, turned off",
            systemImage: store.includeSubtitles ? "captions.bubble.fill" : "captions.bubble",
            color: store.includeSubtitles ? CueFetchTheme.green : CueFetchTheme.orange
        )
    }

    private var toolsCard: ConfidenceCardData {
        if store.toolStatus.ytdlpPath == nil {
            return ConfidenceCardData(
                title: "Tools",
                value: "Missing yt-dlp",
                detail: "Install before download",
                systemImage: "wrench.and.screwdriver.fill",
                color: .red
            )
        }

        if store.currentPlan?.requiredTools.contains(.ffmpeg) == true,
           !store.toolStatus.isFFmpegInstalled {
            return ConfidenceCardData(
                title: "Tools",
                value: "Missing FFmpeg",
                detail: "Required by this preset",
                systemImage: "wrench.and.screwdriver.fill",
                color: .red
            )
        }

        if !store.toolStatus.isFFmpegInstalled {
            return ConfidenceCardData(
                title: "Tools",
                value: "yt-dlp ready",
                detail: "FFmpeg optional here",
                systemImage: "wrench.and.screwdriver.fill",
                color: CueFetchTheme.orange
            )
        }

        return ConfidenceCardData(
            title: "Tools",
            value: "Tools ready",
            detail: "yt-dlp + FFmpeg",
            systemImage: "wrench.and.screwdriver.fill",
            color: CueFetchTheme.green
        )
    }
}

private struct ConfidenceCardData: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let color: Color
}

private struct ConfidenceCard: View {
    let card: ConfidenceCardData

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: card.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(card.color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(card.value)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)

                Text(card.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .cuePanel(radius: 7)
        .accessibilityElement(children: .combine)
    }
}

private enum ErrorRecoveryAction: Equatable {
    case retryAnalysis
    case retryAnalysisWithCookies
    case enableCookies
    case retryDownload
    case openSettings
    case none
}

private struct ErrorRecoveryData {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color
    let actionTitle: String
    let actionIcon: String
    let action: ErrorRecoveryAction
}

private struct ErrorRecoveryPanel: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        let recovery = recoveryData

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: recovery.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(recovery.color)
                .frame(width: 20)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(recovery.title)
                    .font(.system(size: 13.5, weight: .semibold))

                Text(recovery.detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.lastErrorMessage)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if recovery.action != .none {
                Button {
                    perform(recovery.action)
                } label: {
                    Label(recovery.actionTitle, systemImage: recovery.actionIcon)
                        .frame(minWidth: 112)
                }
                .buttonStyle(.bordered)
                .disabled(store.isAnalyzing || store.isDownloading)
            }
        }
        .padding(10)
        .background(recovery.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(recovery.color.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var recoveryData: ErrorRecoveryData {
        let message = store.lastErrorMessage
        let retryAction: ErrorRecoveryAction = store.candidate == nil ? .retryAnalysis : .retryDownload
        let kind = DownloadErrorClassifier.kind(
            for: message,
            ytdlpMissing: store.toolStatus.ytdlpPath == nil
        )

        switch kind {
        case .missingYTDLP:
            return ErrorRecoveryData(
                title: "yt-dlp is missing",
                detail: "Install yt-dlp or refresh the tool paths before trying again.",
                systemImage: "wrench.and.screwdriver.fill",
                color: .red,
                actionTitle: "Settings",
                actionIcon: "gearshape",
                action: .openSettings
            )

        case .safariCookiePermissionDenied:
            return ErrorRecoveryData(
                title: "Safari cookie access blocked",
                detail: "macOS denied access to Safari cookies. Turn Safari cookies off here, or grant access before retrying.",
                systemImage: "lock.shield.fill",
                color: CueFetchTheme.orange,
                actionTitle: "Settings",
                actionIcon: "gearshape",
                action: .openSettings
            )

        case .cookiesRequired:
            let action: ErrorRecoveryAction = store.candidate == nil ? .retryAnalysisWithCookies : .enableCookies
            return ErrorRecoveryData(
                title: "Sign-in may be required",
                detail: "CueFetch can ask yt-dlp to use Safari cookies for this site.",
                systemImage: "person.crop.circle.badge.exclamationmark",
                color: CueFetchTheme.orange,
                actionTitle: store.candidate == nil ? "Retry with Cookies" : "Enable Cookies",
                actionIcon: "safari",
                action: action
            )

        case .drmProtected:
            return ErrorRecoveryData(
                title: "DRM-protected media",
                detail: "CueFetch will not try to bypass protected streams.",
                systemImage: "lock.fill",
                color: .red,
                actionTitle: "",
                actionIcon: "",
                action: .none
            )

        case .unsupported:
            return ErrorRecoveryData(
                title: "This site is not supported here",
                detail: "The link could not be handled by the local yt-dlp install.",
                systemImage: "xmark.octagon.fill",
                color: .red,
                actionTitle: "Retry",
                actionIcon: "arrow.clockwise",
                action: retryAction
            )

        case .timeoutOrNetwork:
            return ErrorRecoveryData(
                title: "Connection timed out",
                detail: "The site did not respond in time. A retry may succeed.",
                systemImage: "clock.arrow.circlepath",
                color: CueFetchTheme.orange,
                actionTitle: "Retry",
                actionIcon: "arrow.clockwise",
                action: retryAction
            )

        case .general:
            return ErrorRecoveryData(
                title: store.candidate == nil ? "Could not analyze link" : "Download failed",
                detail: "The original yt-dlp error is preserved below for troubleshooting.",
                systemImage: "exclamationmark.triangle.fill",
                color: CueFetchTheme.orange,
                actionTitle: "Retry",
                actionIcon: "arrow.clockwise",
                action: retryAction
            )
        }
    }

    private func perform(_ action: ErrorRecoveryAction) {
        switch action {
        case .retryAnalysis:
            store.retryAnalysis()
        case .retryAnalysisWithCookies:
            store.retryAnalysisWithCookies()
        case .enableCookies:
            store.addCookies()
        case .retryDownload:
            store.startDownload()
        case .openSettings:
            store.refreshToolStatus()
            store.isShowingSettings = true
        case .none:
            break
        }
    }
}

private struct AccessLine: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        let accessState = store.candidate?.accessState ?? .unsupported

        HStack(spacing: 13) {
            Image(systemName: "globe")
                .font(.system(size: 17, weight: .medium))
                .frame(width: 22)
                .foregroundStyle(.secondary)

            Text("Access")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .leading)

            Label(accessState.rawValue, systemImage: accessIcon(for: accessState))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accessColor(for: accessState))

            if accessState == .cookiesRequired {
                Button("Add Cookies...") {
                    store.addCookies()
                }
                .buttonStyle(.bordered)
                .padding(.leading, 12)
                .disabled(store.isDownloading)
            }
        }
    }

    private func accessIcon(for state: AccessState) -> String {
        switch state {
        case .available: "checkmark.circle.fill"
        case .cookiesRequired: "exclamationmark.triangle.fill"
        case .unsupported: "xmark.octagon.fill"
        case .drmProtected: "lock.fill"
        }
    }

    private func accessColor(for state: AccessState) -> Color {
        switch state {
        case .available: CueFetchTheme.green
        case .cookiesRequired: CueFetchTheme.orange
        case .unsupported, .drmProtected: .red
        }
    }
}

private struct ProfileSection: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        HStack(spacing: 12) {
            Text("Profile")
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            Menu {
                ForEach(DownloadProfile.all) { profile in
                    Button {
                        store.applyProfile(profile)
                    } label: {
                        Label(profile.name, systemImage: profileIcon(for: profile.id))
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: profileIcon(for: store.selectedProfile.id))
                        .foregroundStyle(CueFetchTheme.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.selectedProfile.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(store.selectedProfile.summary)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .cuePanel(radius: 6)
            }
            .buttonStyle(.plain)
            .disabled(store.isDownloading)
        }
    }

    private func profileIcon(for id: String) -> String {
        switch id {
        case "editing": "film"
        case "audio": "waveform"
        case "archive": "externaldrive"
        case "short-clips": "rectangle.stack"
        default: "slider.horizontal.3"
        }
    }
}

private struct DestinationSection: View {
    @ObservedObject var store: DownloadStore

    private var finderTitle: String {
        store.lastDownloadedPath.isEmpty ? "Open Folder" : "Show Download"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("Destination")
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            HStack(spacing: 9) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)
                Text(store.destination)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .cuePanel(radius: 6)
            .layoutPriority(1)

            Button("Change...") {
                store.chooseDestination()
            }
            .frame(width: 82, height: 34)
            .disabled(store.isDownloading)

            Button {
                store.revealLastDownload()
            } label: {
                Label(finderTitle, systemImage: "folder")
                    .frame(width: 132, height: 34)
            }
        }
    }
}

private struct PresetPicker: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        HStack(spacing: 18) {
            Text("Output preset")
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            HStack(spacing: 0) {
                ForEach(OutputPreset.allCases) { preset in
                    Button {
                        store.selectPreset(preset)
                    } label: {
                        VStack(spacing: 2) {
                            Text(preset.rawValue)
                                .font(.system(size: 13, weight: store.selectedPreset == preset ? .semibold : .regular))
                                .lineLimit(1)
                            Text(preset.subtitle)
                                .font(.system(size: 10.5))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(store.selectedPreset == preset ? .white : .primary)
                        .background(store.selectedPreset == preset ? CueFetchTheme.blue : Color.clear)
                    }
                    .buttonStyle(.plain)

                    if preset != OutputPreset.allCases.last {
                        Rectangle()
                            .fill(CueFetchTheme.divider)
                            .frame(width: 1, height: 38)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(CueFetchTheme.border, lineWidth: 1)
            }
            .disabled(store.isDownloading)
        }
    }
}

private struct ActionSection: View {
    @ObservedObject var store: DownloadStore

    private var finderTitle: String {
        store.lastDownloadedPath.isEmpty ? "Open Folder" : "Show Download"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SubtitleControl(store: store)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                Button {
                    store.revealLastDownload()
                } label: {
                    Label(finderTitle, systemImage: "folder")
                        .frame(width: 142, height: 36)
                }

                Button {
                    if store.isDownloading {
                        store.cancelDownload()
                    } else {
                        store.startDownload()
                    }
                } label: {
                    Label(store.isDownloading ? "Cancel" : "Download", systemImage: store.isDownloading ? "xmark" : "arrow.down.to.line")
                        .frame(width: 126, height: 36)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canDownload && !store.isDownloading)
            }

            if store.isDownloading || !store.lastDownloadedPath.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Image(systemName: store.isDownloading ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(store.isDownloading ? CueFetchTheme.blue : CueFetchTheme.green)

                        Text(store.isDownloading ? store.statusMessage : "Download completed")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(Int(store.downloadProgress * 100))%")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: store.downloadProgress)
                        .progressViewStyle(.linear)
                        .tint(store.isDownloading ? CueFetchTheme.blue : CueFetchTheme.green)
                        .frame(maxWidth: .infinity)

                    if !store.isDownloading {
                        HStack(spacing: 8) {
                            Button {
                                store.revealLastDownload()
                            } label: {
                                Label("Show Download in Finder", systemImage: "folder")
                                    .frame(maxWidth: .infinity)
                            }

                            Button {
                                store.copyDownloadReceipt()
                            } label: {
                                Label("Copy Redacted Receipt", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(!store.canCopyReceipt)
                        }
                    }
                }
                .padding(10)
                .background(CueFetchTheme.blueSoft.opacity(store.isDownloading ? 0.65 : 0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(CueFetchTheme.border, lineWidth: 1)
                }
            }

            if case .cancelled = store.runState {
                Label("Download cancelled", systemImage: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cuePanel(radius: 8)
            }
        }
    }
}

private struct SubtitleControl: View {
    @ObservedObject var store: DownloadStore

    private var detectedLanguages: [String] {
        store.candidate?.subtitleLanguages ?? []
    }

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Download subtitles", isOn: Binding(
                get: { store.includeSubtitles },
                set: { store.setIncludeSubtitles($0) }
            ))
                .toggleStyle(.switch)
                .font(.system(size: 13))
                .lineLimit(1)

            if store.includeSubtitles {
                Picker("Subtitle languages", selection: Binding(
                    get: { store.selectedSubtitleLanguages },
                    set: { store.setSubtitleLanguages($0) }
                )) {
                    Text("All available")
                        .tag("all,-live_chat")

                    if store.selectedSubtitleLanguages != "all,-live_chat",
                       !detectedLanguages.contains(store.selectedSubtitleLanguages) {
                        Text("Saved: \(subtitleLanguageLabel(for: store.selectedSubtitleLanguages))")
                            .tag(store.selectedSubtitleLanguages)
                    }

                    ForEach(detectedLanguages, id: \.self) { language in
                        Text(subtitleLanguageLabel(for: language))
                            .tag(language)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }
        }
        .disabled(store.isDownloading)
    }

    private func subtitleLanguageLabel(for code: String) -> String {
        switch code {
        case "en": "English"
        case "es": "Spanish"
        case "fr": "French"
        case "pt": "Portuguese"
        case "de": "German"
        case "it": "Italian"
        case "ja": "Japanese"
        case "ko": "Korean"
        case "zh", "zh-Hans", "zh-Hant": "Chinese"
        default: code.uppercased()
        }
    }
}

private struct CommandPreviewView: View {
    let command: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Command preview")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            Text(command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}
