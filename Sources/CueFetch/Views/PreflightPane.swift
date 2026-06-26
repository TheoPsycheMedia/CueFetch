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
        .background(Color.white)
    }
}

private struct LoadedPreflightPane: View {
    @ObservedObject var store: DownloadStore
    let candidate: DownloadCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderSection(store: store, candidate: candidate)

            Divider()

            DestinationSection(store: store)

            PresetPicker(store: store)

            FormatTableView(store: store)
                .layoutPriority(1)

            ActionSection(store: store)

            CommandPreviewView(command: store.lastCommandPreview)
        }
        .padding(.top, 14)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
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
                    Image(systemName: store.toolStatus.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(store.toolStatus.isReady ? CueFetchTheme.green : CueFetchTheme.orange)
                    Text(store.toolStatus.isReady ? "yt-dlp is ready" : "yt-dlp was not found")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
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
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .cuePanel(radius: 6)
            .layoutPriority(1)

            Button("Change...") {
                store.chooseDestination()
            }
            .frame(width: 82, height: 34)

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
                        store.selectedPreset = preset
                        store.updateCommandPreview()
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
                Toggle("Download subtitles if available", isOn: $store.includeSubtitles)
                    .toggleStyle(.switch)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .onChange(of: store.includeSubtitles) {
                        store.updateCommandPreview()
                    }

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
                        Button {
                            store.revealLastDownload()
                        } label: {
                            Label("Show Download in Finder", systemImage: "folder")
                                .frame(maxWidth: .infinity)
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
