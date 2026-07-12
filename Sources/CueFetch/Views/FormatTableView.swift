import CueFetchCore
import SwiftUI

struct FormatTableView: View {
    @ObservedObject var store: DownloadStore

    private var formats: [MediaFormat] {
        store.candidate?.formats ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Available formats")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Label("Best use", systemImage: "sparkles")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(CueFetchTheme.blue)
                    .labelStyle(.titleAndIcon)
            }

            if formats.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(CueFetchTheme.orange)
                    Text("No downloadable formats were reported for this item.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(14)
                .cuePanel(radius: 7)
            } else {
                ScrollView {
                    ViewThatFits(in: .horizontal) {
                        FullFormatTable(store: store)
                        CompactFormatList(store: store)
                    }
                }
                .scrollIndicators(.visible)
                .frame(minHeight: 172, idealHeight: 190, maxHeight: 214)
            }
        }
    }
}

private struct FullFormatTable: View {
    @ObservedObject var store: DownloadStore

    private var formats: [MediaFormat] {
        store.candidate?.formats ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            FormatHeaderRow()

            ForEach(formats) { format in
                FormatRow(
                    format: format,
                    selected: format.id == store.selectedFormatID,
                    action: {
                        store.selectFormat(id: format.id)
                    }
                )
                .disabled(store.isDownloading)

                if format.id != formats.last?.id {
                    Divider()
                }
            }
        }
        .cuePanel(radius: 7)
    }
}

private struct CompactFormatList: View {
    @ObservedObject var store: DownloadStore

    private var formats: [MediaFormat] {
        store.candidate?.formats ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(formats) { format in
                Button {
                    store.selectFormat(id: format.id)
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .stroke(format.id == store.selectedFormatID ? CueFetchTheme.blue : CueFetchTheme.border, lineWidth: format.id == store.selectedFormatID ? 6 : 1.5)
                            .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(format.quality)
                                .font(.system(size: 13.5, weight: .semibold))
                            Text("\(format.container) • \(format.videoCodec) • \(format.audio)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(format.estimatedSize)
                                .font(.system(size: 12.5, weight: .medium))
                                .lineLimit(1)
                            FormatRecommendationBadge(format: format)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .contentShape(Rectangle())
                    .background(format.id == store.selectedFormatID ? CueFetchTheme.blueSoft.opacity(0.55) : Color.clear)
                }
                .buttonStyle(.plain)
                .disabled(store.isDownloading)

                if format.id != formats.last?.id {
                    Divider()
                }
            }
        }
        .cuePanel(radius: 7)
    }
}

private struct FormatHeaderRow: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 38)
            TableHeading("Quality", width: 110)
            TableHeading("Container", width: 72)
            TableHeading("Video Codec", width: 98)
            TableHeading("Audio", width: 112)
            TableHeading("Estimated size", width: 100)
            TableHeading("Subtitles", width: 72)
            TableHeading("Best use", width: 135)
            Spacer()
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(height: 30)
        .background(Color.black.opacity(0.025))
    }
}

private struct TableHeading: View {
    let title: String
    let width: CGFloat

    init(_ title: String, width: CGFloat) {
        self.title = title
        self.width = width
    }

    var body: some View {
        Text(title)
            .frame(width: width, alignment: .leading)
    }
}

private struct FormatRow: View {
    let format: MediaFormat
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(selected ? CueFetchTheme.blue : CueFetchTheme.border, lineWidth: selected ? 6 : 1.5)
                        .frame(width: 20, height: 20)
                }
                .frame(width: 38)

                TableCell(format.quality, width: 110, weight: .medium)
                TableCell(format.container, width: 72)
                TableCell(format.videoCodec, width: 98)
                TableCell(format.audio, width: 112)
                TableCell(format.estimatedSize, width: 100)
                TableCell(format.subtitles ? "Yes" : "-", width: 72)
                FormatRecommendationCell(format: format)
                    .frame(width: 135, alignment: .leading)

                Spacer()
            }
            .font(.system(size: 13))
            .foregroundStyle(.primary)
            .frame(height: 44)
            .contentShape(Rectangle())
            .background(selected ? CueFetchTheme.blueSoft.opacity(0.55) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

private struct FormatRecommendation {
    let label: String
    let detail: String
    let systemImage: String
    let color: Color
}

private extension MediaFormat {
    var recommendation: FormatRecommendation {
        if !isCueFetchCompatible {
            return FormatRecommendation(
                label: "Convert",
                detail: "May need conversion",
                systemImage: "exclamationmark.triangle.fill",
                color: CueFetchTheme.orange
            )
        }

        if isAudioOnly {
            return FormatRecommendation(
                label: "Audio pick",
                detail: "Music-ready file",
                systemImage: "waveform",
                color: CueFetchTheme.green
            )
        }

        if quality.contains("1080p") {
            return FormatRecommendation(
                label: "Editor pick",
                detail: "Balanced MP4",
                systemImage: "checkmark.seal.fill",
                color: CueFetchTheme.green
            )
        }

        if quality.contains("2160p") || quality.contains("1440p") || quality.contains("4K") {
            return FormatRecommendation(
                label: "Archive",
                detail: "Highest detail",
                systemImage: "externaldrive.fill",
                color: CueFetchTheme.blue
            )
        }

        return FormatRecommendation(
            label: "Smaller file",
            detail: "Quick transfer",
            systemImage: "arrow.down.circle.fill",
            color: CueFetchTheme.blue
        )
    }

    private var isCueFetchCompatible: Bool {
        compatibilityKind != .requiresConversion
    }
}

private struct FormatRecommendationBadge: View {
    let format: MediaFormat

    var body: some View {
        let recommendation = format.recommendation

        Label(recommendation.label, systemImage: recommendation.systemImage)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(recommendation.color)
            .lineLimit(1)
            .labelStyle(.titleAndIcon)
    }
}

private struct FormatRecommendationCell: View {
    let format: MediaFormat

    var body: some View {
        let recommendation = format.recommendation

        HStack(spacing: 8) {
            Image(systemName: recommendation.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(recommendation.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.label)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                Text(recommendation.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TableCell: View {
    let title: String
    let width: CGFloat
    var weight: Font.Weight

    init(_ title: String, width: CGFloat, weight: Font.Weight = .regular) {
        self.title = title
        self.width = width
        self.weight = weight
    }

    var body: some View {
        Text(title)
            .fontWeight(weight)
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
    }
}
