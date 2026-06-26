import CueFetchCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: DownloadStore

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(store: store)

            HStack(spacing: 0) {
                NewDownloadPane(store: store)
                    .frame(width: 300)

                Divider()

                PreflightPane(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            BottomStatusBar(store: store)
                .frame(height: 44)
        }
        .background(CueFetchTheme.page)
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
            HStack(spacing: 6) {
                Text("CueFetch")
                    .font(.system(size: 20, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.statusMessage = store.recentLinks.isEmpty ? "No links analyzed yet" : "Recent links are shown in the left column"
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .frame(minWidth: 88)
            }
            .buttonStyle(.bordered)

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
                    .fill(store.toolStatus.isReady ? CueFetchTheme.green : CueFetchTheme.orange)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: store.toolStatus.isReady ? "checkmark" : "exclamationmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                Text(store.toolStatus.isReady ? "Up to date" : "Needs yt-dlp")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .trailing)
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
                    TextEditor(text: $store.inputURL)
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
                .disabled(!store.canAnalyze || store.isAnalyzing)
            }

            Divider()

            HStack {
                Text("Recent links")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Clear") {
                    store.clearRecentLinks()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(store.recentLinks.isEmpty)
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
            } else {
                VStack(spacing: 0) {
                    ForEach(store.recentLinks) { link in
                        RecentLinkRow(link: link, selected: link.url == store.candidate?.url) {
                            store.selectRecent(link)
                        }

                        if link.id != store.recentLinks.last?.id {
                            Divider()
                                .padding(.leading, 128)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 18)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .background(Color.white.opacity(0.76))
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
                Text("Supported sites (1700+)")
                    .underline()
                    .foregroundStyle(CueFetchTheme.blue)
            }

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

            Button("Check for updates") {
                store.refreshToolStatus()
            }
            .buttonStyle(.plain)
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
