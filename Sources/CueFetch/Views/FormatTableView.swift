import CueFetchCore
import SwiftUI

struct FormatTableView: View {
    @ObservedObject var store: DownloadStore

    private var formats: [MediaFormat] {
        store.candidate?.formats ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available formats")
                .font(.system(size: 15, weight: .semibold))

            ScrollView {
                ViewThatFits(in: .horizontal) {
                    FullFormatTable(store: store)
                    CompactFormatList(store: store)
                }
            }
            .scrollIndicators(.visible)
            .frame(minHeight: 208, idealHeight: 214, maxHeight: 214)
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
                        store.selectedFormatID = format.id
                        store.updateCommandPreview()
                    }
                )

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
                    store.selectedFormatID = format.id
                    store.updateCommandPreview()
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
                            Label("QuickTime", systemImage: "checkmark.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(CueFetchTheme.green)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .contentShape(Rectangle())
                    .background(format.id == store.selectedFormatID ? CueFetchTheme.blueSoft.opacity(0.55) : Color.clear)
                }
                .buttonStyle(.plain)

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
            TableHeading("Compatibility", width: 135)
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

                HStack(spacing: 10) {
                    Text(format.compatibility)
                        .lineLimit(2)
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(CueFetchTheme.green)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
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
