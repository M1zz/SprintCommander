import SwiftUI

// MARK: - Page Header
struct PageHeader: View {
    let title: String
    let subtitle: String
    var primaryAction: String? = nil
    var primaryIcon: String? = nil
    var onPrimary: (() -> Void)? = nil
    var secondaryAction: String? = nil
    var onSecondary: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(hex: "A8A8D8")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.3))
            }

            Spacer()

            HStack(spacing: 10) {
                if let secondaryAction {
                    GhostButton(title: secondaryAction, action: onSecondary ?? {})
                }
                if let primaryAction {
                    PrimaryButton(title: primaryAction, icon: primaryIcon, action: onPrimary ?? {})
                }
            }
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Buttons
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color(hex: "4FACFE"), Color(hex: "667EEA")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .cornerRadius(8)
            .shadow(color: Color(hex: "4FACFE").opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let label: String
    let value: String
    let color: Color
    let change: String
    var isUp: Bool = true // kept for API compat, no longer affects display
    let accentGradient: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 10)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(-1)
                .foregroundColor(color)
                .padding(.bottom, 6)

            if !change.isEmpty && change != "-" {
                Text(change)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(alignment: .top) {
            LinearGradient(colors: accentGradient, startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)
                .clipShape(
                    UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Section Header
struct SectionHeaderView: View {
    let title: String
    var tabs: [String] = []
    @Binding var selectedTab: Int

    init(title: String, tabs: [String] = [], selectedTab: Binding<Int> = .constant(0)) {
        self.title = title
        self.tabs = tabs
        self._selectedTab = selectedTab
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            if !tabs.isEmpty {
                HStack(spacing: 2) {
                    ForEach(tabs.indices, id: \.self) { index in
                        Text(tabs[index])
                            .font(.system(size: 12))
                            .foregroundColor(selectedTab == index ? .white : .white.opacity(0.3))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                selectedTab == index ? Color.white.opacity(0.1) : Color.clear
                            )
                            .cornerRadius(5)
                            .onTapGesture { selectedTab = index }
                    }
                }
                .padding(2)
                .background(Color.white.opacity(0.04))
                .cornerRadius(7)
            }
        }
    }
}

// MARK: - Card Container
struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

// MARK: - Progress Bar
struct ProgressBarView: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.06))

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(progress / 100, 1.0))
                    .animation(.easeOut(duration: 0.6), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Form Field
struct FormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

// MARK: - Form Picker
struct FormPicker<T: Hashable>: View {
    let label: String
    let options: [T]
    @Binding var selection: T
    let titleForOption: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            HStack(spacing: 4) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection == option
                    Button {
                        selection = option
                    } label: {
                        Text(titleForOption(option))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color(hex: "4FACFE").opacity(0.3) : Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Version Badge
struct VersionBadge: View {
    let version: String
    var color: Color = Color(hex: "4FACFE")

    var body: some View {
        if !version.isEmpty {
            Text("v\(version)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        }
    }
}

// MARK: - Tag Badge
struct TagBadge: View {
    let text: String

    var color: Color {
        TagStyle.color(for: text)
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}
