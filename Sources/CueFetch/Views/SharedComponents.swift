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
                    Text("Configure downloads, tools, and history.")
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

                            Button {
                                store.openDestinationFolder()
                            } label: {
                                Label("Open in Finder", systemImage: "arrow.up.forward.app")
                            }

                            Spacer()
                        }

                        Toggle("Download subtitles by default", isOn: $store.includeSubtitles)
                            .toggleStyle(.switch)
                            .onChange(of: store.includeSubtitles) {
                                store.updateCommandPreview()
                            }

                        Toggle("Use Safari cookies when needed", isOn: $store.useBrowserCookies)
                            .toggleStyle(.switch)
                            .onChange(of: store.useBrowserCookies) {
                                store.updateCommandPreview()
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
                    }

                    SettingsSection(title: "History") {
                        SettingLine(title: "Recent links", value: "\(store.recentLinks.count)")

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
