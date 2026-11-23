import SwiftUI
import AppKit
import Combine

/// The text typed into the custom palette field. Kept in an object because
/// @State needs full Xcode on the newest SDK.
final class CustomPaletteDraft: ObservableObject {
    @Published var text: String
    @Published var message: String?

    init() {
        text = PaletteStore.shared.customColors.map(ColorPalette.hexString) ?? ""
    }
}

struct SettingsView: View {
    @ObservedObject var palettes = PaletteStore.shared
    @StateObject var draft = CustomPaletteDraft()

    var body: some View {
        Form {
            Section("Palette") {
                ForEach(ColorPalette.presets) { palette in
                    PaletteRow(palette: palette, isSelected: palettes.selectionID == palette.id) {
                        palettes.select(palette.id)
                    }
                }
                if let custom = palettes.customPalette {
                    PaletteRow(palette: custom, isSelected: palettes.selectionID == custom.id) {
                        palettes.select(custom.id)
                    }
                }
            }

            Section {
                TextField("Colors", text: $draft.text,
                          prompt: Text("#93b7be #554348 … or a coolors.co link"))
                    .onSubmit(applyCustom)
                HStack {
                    if let message = draft.message {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Button("Use These Colors", action: applyCustom)
                }
            } header: {
                Text("Custom palette")
            } footer: {
                Text("Enter five hex codes, or paste a link from coolors.co. The darkest color becomes text, the lightest becomes the background, and the most colorful one becomes the accent.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            let warnings = palettes.current.roles.warnings
            if !warnings.isEmpty {
                Section {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 560)
        .background(WindowLevel(floating: true))
    }

    private func applyCustom() {
        let colors = ColorPalette.parseHexList(draft.text)
        guard colors.count == 5 else {
            draft.message = colors.isEmpty
                ? "No hex codes found."
                : "Found \(colors.count) colors. Enter exactly five."
            return
        }
        draft.message = nil
        draft.text = ColorPalette.hexString(colors)
        palettes.useCustom(colors)
    }
}

struct PaletteRow: View {
    let palette: ColorPalette
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let roles = palette.roles

        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    // Shown in job order: background, gray, gray, accent, text.
                    let swatches = [roles.lightest, roles.lighterGray, roles.darkerGray, roles.accent, roles.darkest]
                    ForEach(Array(swatches.enumerated()), id: \.offset) { _, hex in
                        Color(hex: hex).frame(width: 22, height: 22)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12))
                )

                Text(palette.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Keeps the Settings window above the floating checklist while it's open.
struct WindowLevel: NSViewRepresentable {
    let floating: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { view.window?.level = floating ? .floating : .normal }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
