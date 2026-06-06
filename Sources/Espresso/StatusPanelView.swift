import SwiftUI

/// Observable session state shared between AppDelegate and the popover UI.
final class SessionModel: ObservableObject {
    @Published var isActive = false
    @Published var selectedIndex: Int?
}

/// The left-click popover panel: current state, duration picker, and clear button.
struct StatusPanelView: View {
    @ObservedObject var model: SessionModel
    let options: [String]
    let onSelect: (Int) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            Divider()
            Text("Keep awake for")
                .font(.callout)
                .foregroundStyle(.secondary)
            durationPicker
            Divider()
            HStack {
                Spacer()
                Button("Clear", action: onClear)
                    .disabled(!model.isActive)
            }
        }
        .padding(10)
        .frame(width: 240)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Circle()
                    .fill(model.isActive ? Color.green : Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 8, height: 8)
                Text(model.isActive ? "Active" : "Inactive")
                    .font(.headline)
            }
            Text(model.isActive ? "system sleep is prevented" : "system sleep is allowed")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var durationPicker: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Text(options[index])
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(model.selectedIndex == index ? Color.primary.opacity(0.18) : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }
}
