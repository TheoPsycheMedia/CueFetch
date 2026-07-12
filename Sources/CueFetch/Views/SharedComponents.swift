import CueFetchCore
import SwiftUI

struct ThumbnailView: View {
    let name: String

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            }
    }
}

struct MediaThumbnailView: View {
    let name: String
    let urlString: String?

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.04))
                case .failure:
                    ThumbnailView(name: name)
                @unknown default:
                    ThumbnailView(name: name)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            }
        } else {
            ThumbnailView(name: name)
        }
    }
}

struct SiteBadge: View {
    let site: SiteKind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(background)
                .frame(width: 22, height: 22)
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(site.rawValue)
    }

    private var label: String {
        switch site {
        case .youtube: "▶"
        case .vimeo: "v"
        case .tiktok: "♪"
        case .x: "X"
        case .generic: "•"
        }
    }

    private var background: Color {
        switch site {
        case .youtube: .red
        case .vimeo: Color(red: 0.08, green: 0.62, blue: 0.92)
        case .tiktok: .black
        case .x: .black
        case .generic: .gray
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: DownloadStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 22, weight: .semibold))
                    Text("Configure downloads, tools, privacy, and session history.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(22)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsSection(title: "Downloads") {
                        SettingLine(title: "Destination", value: store.destination)

                        HStack(spacing: 10) {
                            Button {
                                store.chooseDestination()
                            } label: {
                                Label("Change Folder", systemImage: "folder")
                            }
                            .disabled(store.isDownloading)

                            Button {
                                store.openDestinationFolder()
                            } label: {
                                Label("Open in Finder", systemImage: "arrow.up.forward.app")
                            }

                            Spacer()
                        }

                        Toggle("Download subtitles by default", isOn: Binding(
                            get: { store.includeSubtitles },
                            set: { store.setIncludeSubtitles($0) }
                        ))
                            .toggleStyle(.switch)
                            .disabled(store.isDownloading)

                        Toggle("Use Safari cookies for the current link", isOn: Binding(
                            get: { store.useBrowserCookies },
                            set: { store.setUseBrowserCookies($0) }
                        ))
                            .toggleStyle(.switch)
                            .disabled(store.isDownloading)

                        Text("Cookie access is never persisted and resets when you change links or finish a download.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    SettingsSection(title: "Profiles") {
                        ForEach(DownloadProfile.all) { profile in
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: settingsProfileIcon(for: profile.id))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(profile.id == store.selectedProfileID ? CueFetchTheme.blue : .secondary)
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("\(profile.summary) -> \(profile.destination)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Button(profile.id == store.selectedProfileID ? "Applied" : "Apply") {
                                    store.applyProfile(profile)
                                }
                                .disabled(profile.id == store.selectedProfileID || store.isDownloading)
                            }

                            if profile.id != DownloadProfile.all.last?.id {
                                Divider()
                            }
                        }
                    }

                    SettingsSection(title: "Tools") {
                        SettingLine(title: "yt-dlp", value: store.toolStatus.ytdlpPath ?? "Not found")
                        SettingLine(title: "Version", value: store.toolStatus.ytdlpVersion ?? "-")
                        SettingLine(title: "ffmpeg", value: store.toolStatus.ffmpegPath ?? "Not found")

                        HStack {
                            Button {
                                store.refreshToolStatus()
                            } label: {
                                Label("Refresh Tools", systemImage: "arrow.clockwise")
                            }

                            Spacer()
                        }
                    }

                    SettingsSection(title: "Legal") {
                        LegalParagraph(
                            "CueFetch is an independent macOS front-end that invokes yt-dlp and may use FFmpeg when available on this Mac."
                        )
                        LegalParagraph(
                            "CueFetch is not affiliated with yt-dlp, FFmpeg, YouTube, Vimeo, TikTok, X, or any supported site."
                        )
                        LegalParagraph(
                            "Use CueFetch only for media you are authorized to access, download, archive, or transform. CueFetch does not bypass DRM."
                        )

                        HStack(spacing: 10) {
                            Button("License") {
                                store.openBundledLegalDocument(named: "LICENSE")
                            }
                            Button("Notice") {
                                store.openBundledLegalDocument(named: "NOTICE")
                            }
                            Button("Third-Party Notices") {
                                store.openBundledLegalDocument(named: "THIRD_PARTY_NOTICES")
                            }
                            Spacer()
                        }
                    }

                    SettingsSection(title: "History") {
                        SettingLine(title: "Session links", value: "\(store.recentLinks.count)")

                        LegalParagraph(
                            "Recent URLs stay in memory for this app session only. CueFetch removes legacy persisted history at launch."
                        )

                        HStack {
                            Button(role: .destructive) {
                                store.clearRecentLinks()
                            } label: {
                                Label("Clear History", systemImage: "trash")
                            }
                            .disabled(store.recentLinks.isEmpty)

                            Spacer()
                        }
                    }
                }
                .padding(22)
            }
        }
        .background(CueFetchTheme.page)
    }

    private func settingsProfileIcon(for id: String) -> String {
        switch id {
        case "editing": "film"
        case "audio": "waveform"
        case "archive": "externaldrive"
        case "short-clips": "rectangle.stack"
        default: "slider.horizontal.3"
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cuePanel(radius: 8)
        }
    }
}

private struct LegalParagraph: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 112, alignment: .leading)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
