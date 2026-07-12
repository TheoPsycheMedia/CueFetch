import CueFetchCore
import SwiftUI

struct DownloadInputControlState: Equatable {
    let hasAnalyzableInput: Bool
    let isAnalyzing: Bool
    let isDownloading: Bool

    var isURLInputEnabled: Bool {
        !isDownloading
    }

    var isAnalyzeEnabled: Bool {
        hasAnalyzableInput && !isAnalyzing && !isDownloading
    }

    var isRecentSelectionEnabled: Bool {
        !isDownloading
    }
}

struct ContentView: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        LiquidOrbitView(store: store)
        .onAppear {
            store.refreshToolStatus()
            store.updateCommandPreview()
        }
        .sheet(isPresented: $store.isShowingSettings) {
            SettingsView(store: store)
                .frame(width: 560, height: 520)
        }
    }
}

private struct TopBarView: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        HStack(spacing: 12) {
            Text("CueFetch")
                .font(.system(size: 20, weight: .semibold))

            Spacer()

            Label("Session history", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Button {
                store.refreshToolStatus()
                store.isShowingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .frame(minWidth: 96)
            }
            .buttonStyle(.bordered)

            HStack(spacing: 8) {
                Circle()
                    .fill(store.toolStatus.isYTDLPInstalled ? CueFetchTheme.green : CueFetchTheme.orange)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: store.toolStatus.isYTDLPInstalled ? "checkmark" : "exclamationmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                Text(store.toolStatus.isYTDLPInstalled ? "yt-dlp installed" : "Needs yt-dlp")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: 136, alignment: .trailing)
        }
        .padding(.leading, 112)
        .padding(.trailing, 20)
        .frame(height: 54)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CueFetchTheme.divider)
                .frame(height: 1)
        }
    }
}

private struct NewDownloadPane: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("New download")
                    .font(.system(size: 17, weight: .semibold))

                ZStack(alignment: .topLeading) {
                    TextEditor(text: Binding(
                        get: { store.inputURL },
                        set: { store.setInputURL($0) }
                    ))
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .padding(.leading, 34)
                        .padding(.trailing, 10)
                        .padding(.vertical, 10)
                        .frame(height: 96)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(store.inputURL.isEmpty ? CueFetchTheme.blue : CueFetchTheme.border, lineWidth: 1.5)
                        )
                        .disabled(!controlState.isURLInputEnabled)

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "link")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 18)

                        if store.inputURL.isEmpty {
                            Text("Paste a video link from YouTube, Vimeo, TikTok, X, or another supported site")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 14))
                                .lineSpacing(2)
                                .padding(.top, 14)
                                .padding(.trailing, 10)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.leading, 14)
                }

                Button {
                    store.analyzeLink()
                } label: {
                    HStack(spacing: 10) {
                        if store.isAnalyzing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(store.isAnalyzing ? "Analyzing..." : "Analyze Link")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!controlState.isAnalyzeEnabled)

                if let warning = store.pendingIntakeWarning {
                    IntakeWarningPanel(store: store, warning: warning)
                }
            }

            Divider()

            HStack {
                Text("Recent links this session")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Clear") {
                    store.clearRecentLinks()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(store.recentLinks.isEmpty || !controlState.isRecentSelectionEnabled)
            }

            if store.recentLinks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Analyzed links will appear here.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
                .cuePanel(radius: 8)
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.recentLinks) { link in
                            RecentLinkRow(link: link, selected: link.url == store.candidate?.url) {
                                store.selectRecent(link)
                            }
                            .disabled(!controlState.isRecentSelectionEnabled)

                            if link.id != store.recentLinks.last?.id {
                                Divider()
                                    .padding(.leading, 94)
                            }
                        }
                    }
                }
                .scrollIndicators(.automatic)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(.top, 18)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .background(Color.white.opacity(0.76))
    }

    private var controlState: DownloadInputControlState {
        DownloadInputControlState(
            hasAnalyzableInput: store.canAnalyze,
            isAnalyzing: store.isAnalyzing,
            isDownloading: store.isDownloading
        )
    }
}

private struct IntakeWarningPanel: View {
    @ObservedObject var store: DownloadStore
    let warning: URLIntakeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: warning.kind == .multipleLinks ? "link.badge.plus" : "rectangle.stack.badge.play")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CueFetchTheme.orange)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                if warning.kind != .playlist || warning.canAnalyzeSingleVideo {
                    Button {
                        store.analyzePrimaryIntakeURL()
                    } label: {
                        Label(primaryActionTitle, systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isDownloading)
                }

                Button {
                    store.clearIntakeWarning()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(10)
        .background(CueFetchTheme.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CueFetchTheme.orange.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch warning.kind {
        case .multipleLinks:
            "\(warning.urlCount) links pasted"
        case .playlist:
            "Playlist detected"
        case .single, .empty, .invalid:
            "Review link"
        }
    }

    private var detail: String {
        switch warning.kind {
        case .multipleLinks:
            "CueFetch reviews one link at a time. Start with the first detected link or cancel and paste only one."
        case .playlist:
            warning.canAnalyzeSingleVideo
                ? "This URL includes playlist data. CueFetch will analyze only the direct video."
                : "CueFetch downloads one item at a time. Paste a direct video URL instead of a playlist."
        case .single, .empty, .invalid:
            "Confirm what CueFetch should analyze."
        }
    }

    private var primaryActionTitle: String {
        switch warning.kind {
        case .multipleLinks:
            "Analyze First"
        case .playlist:
            "Video Only"
        case .single, .empty, .invalid:
            "Analyze"
        }
    }
}

private struct RecentLinkRow: View {
    let link: RecentLink
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ThumbnailView(name: link.thumbnailName)
                    .frame(width: 74, height: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(link.title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        SiteBadge(site: link.site)
                        Text(link.domain)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(link.dateLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(selected ? CueFetchTheme.blueSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.blue.opacity(0.22), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct BottomStatusBar: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                Text("Site support provided by yt-dlp")
            }
            .foregroundStyle(.secondary)

            Spacer()

            if store.isDownloading {
                ProgressView(value: store.downloadProgress)
                    .frame(width: 180)
                Text("\(Int(store.downloadProgress * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !store.lastErrorMessage.isEmpty {
                Text(store.lastErrorMessage)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.red)
                    .frame(maxWidth: 260, alignment: .trailing)
            } else if !store.lastDownloadedPath.isEmpty {
                Button("Open in Finder") {
                    store.revealLastDownload()
                }
                .buttonStyle(.plain)
                .foregroundStyle(CueFetchTheme.blue)
            }

            HStack(spacing: 8) {
                Image(systemName: "shield")
                Text(store.toolStatus.ytdlpVersion.map { "Using yt-dlp \($0)" } ?? "yt-dlp not found")
            }
            .foregroundStyle(.secondary)

            Link("View Releases", destination: URL(string: "https://github.com/TheoPsycheMedia/CueFetch/releases")!)
                .foregroundStyle(CueFetchTheme.blue)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 20)
        .frame(height: 44)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CueFetchTheme.divider)
                .frame(height: 1)
        }
    }
}
