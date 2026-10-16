import SwiftUI

public struct LogDrawerView: View {
    @ObservedObject var scrcpyService = ScrcpyService.shared
    @Binding var isExpanded: Bool

    public init(isExpanded: Binding<Bool>) {
        self._isExpanded = isExpanded
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Header bar
            HStack {
                Label("Log Terminal (scrcpy / adb)", systemImage: "terminal")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    scrcpyService.logLines.removeAll()
                }) {
                    Text("Bersihkan")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))

            if isExpanded {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            if scrcpyService.logLines.isEmpty {
                                Text("Belum ada log aktif.")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(8)
                            } else {
                                ForEach(Array(scrcpyService.logLines.enumerated()), id: \.offset) { idx, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(line.contains("[error]") ? .red : .primary)
                                        .textSelection(.enabled)
                                        .id(idx)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: 120)
                    .background(Color(NSColor.textBackgroundColor))
                    .onChange(of: scrcpyService.logLines.count) { _ in
                        if let lastIdx = scrcpyService.logLines.indices.last {
                            proxy.scrollTo(lastIdx, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}
