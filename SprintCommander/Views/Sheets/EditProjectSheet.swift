import SwiftUI

struct EditProjectSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let project: Project

    @State private var name: String
    @State private var icon: String
    @State private var desc: String
    @State private var sprint: String
    @State private var sourcePath: String
    @State private var landingURL: String
    @State private var appStoreURL: String
    @State private var downloadPrice: String
    @State private var monthlyPrice: String
    @State private var yearlyPrice: String
    @State private var lifetimePrice: String
    @State private var selectedColorIndex: Int
    @State private var selectedLanguages: Set<String>

    let emojiOptions = ["📱", "🌐", "🔧", "📊", "🎨", "🚀", "💬", "🛒", "🔒", "📦", "🎮", "📡"]
    static let availableLanguages = [
        "한국어", "English", "日本語", "中文(简体)", "中文(繁體)",
        "Español", "Français", "Deutsch", "Português", "Italiano",
        "Tiếng Việt", "ไทย", "Bahasa Indonesia", "हिन्दी", "العربية",
        "Русский", "Türkçe", "Polski", "Nederlands", "Svenska"
    ]

    init(project: Project) {
        self.project = project
        _name = State(initialValue: project.name)
        _icon = State(initialValue: project.icon)
        _desc = State(initialValue: project.desc)
        _sprint = State(initialValue: project.sprint)
        _sourcePath = State(initialValue: project.sourcePath)
        _landingURL = State(initialValue: project.landingURL)
        _appStoreURL = State(initialValue: project.appStoreURL)
        _downloadPrice = State(initialValue: project.pricing.downloadPrice)
        _monthlyPrice = State(initialValue: project.pricing.monthlyPrice)
        _yearlyPrice = State(initialValue: project.pricing.yearlyPrice)
        _lifetimePrice = State(initialValue: project.pricing.lifetimePrice)

        let colorIndex = AppStore.palette.firstIndex(where: {
            $0.toHex() == project.color.toHex()
        }) ?? 0
        _selectedColorIndex = State(initialValue: colorIndex)
        _selectedLanguages = State(initialValue: Set(project.languages))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("프로젝트 편집")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                VStack(spacing: 16) {
                    // Project path
                    VStack(alignment: .leading, spacing: 6) {
                        Text("프로젝트 경로")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        HStack(spacing: 8) {
                            TextField("경로를 입력하거나 폴더를 선택하세요", text: $sourcePath)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)

                            Button {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.allowsMultipleSelection = false
                                panel.message = "프로젝트 폴더를 선택하세요"
                                if panel.runModal() == .OK, let url = panel.url {
                                    sourcePath = url.path
                                }
                            } label: {
                                Image(systemName: "folder")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Icon selection
                    VStack(alignment: .leading, spacing: 6) {
                        Text("아이콘")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 6), count: 6), spacing: 6) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button {
                                    icon = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 20))
                                        .frame(width: 36, height: 36)
                                        .background(icon == emoji ? Color(hex: "4FACFE").opacity(0.3) : Color.white.opacity(0.06))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    FormField(label: "프로젝트 이름", text: $name, placeholder: "예: 모바일 앱 리뉴얼")
                    FormField(label: "설명", text: $desc, placeholder: "프로젝트에 대한 간단한 설명")
                    FormField(label: "스프린트", text: $sprint, placeholder: "Sprint 1")
                    FormField(label: "랜딩 페이지 URL", text: $landingURL, placeholder: "https://example.com")
                    FormField(label: "앱스토어 URL", text: $appStoreURL, placeholder: "https://apps.apple.com/app/...")

                    // Pricing section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("가격 정보")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        pricingRow(icon: "arrow.down.circle", label: "다운로드", text: $downloadPrice, placeholder: "무료 또는 ₩4,900")
                        pricingRow(icon: "calendar", label: "월 구독", text: $monthlyPrice, placeholder: "₩4,900")
                        pricingRow(icon: "calendar.badge.clock", label: "연 구독", text: $yearlyPrice, placeholder: "₩49,000")
                        pricingRow(icon: "infinity", label: "평생구매", text: $lifetimePrice, placeholder: "₩99,000")
                    }

                    // Languages section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("지원 다국어")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            if !selectedLanguages.isEmpty {
                                Text("\(selectedLanguages.count)개 선택")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(hex: "4FACFE"))
                            }
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                            ForEach(Self.availableLanguages, id: \.self) { lang in
                                let isSelected = selectedLanguages.contains(lang)
                                Button {
                                    if isSelected {
                                        selectedLanguages.remove(lang)
                                    } else {
                                        selectedLanguages.insert(lang)
                                    }
                                } label: {
                                    Text(lang)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color(hex: "4FACFE").opacity(0.25) : Color.white.opacity(0.04))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isSelected ? Color(hex: "4FACFE").opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Color selection
                    VStack(alignment: .leading, spacing: 6) {
                        Text("색상")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 10), spacing: 6) {
                            ForEach(AppStore.palette.indices, id: \.self) { index in
                                Circle()
                                    .fill(AppStore.palette[index])
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColorIndex == index ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColorIndex = index
                                    }
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider().background(Color.white.opacity(0.06))

            // Actions
            HStack {
                Spacer()
                GhostButton(title: "취소") { dismiss() }
                PrimaryButton(title: "저장", icon: "checkmark") {
                    var updated = project
                    updated.name = name.isEmpty ? project.name : name
                    updated.icon = icon
                    updated.desc = desc
                    updated.sprint = sprint
                    updated.sourcePath = sourcePath
                    updated.landingURL = landingURL
                    updated.appStoreURL = appStoreURL
                    updated.pricing = PricingInfo(
                        downloadPrice: downloadPrice,
                        monthlyPrice: monthlyPrice,
                        yearlyPrice: yearlyPrice,
                        lifetimePrice: lifetimePrice
                    )
                    updated.languages = Self.availableLanguages.filter { selectedLanguages.contains($0) }
                    updated.color = AppStore.palette[selectedColorIndex]
                    store.updateProject(updated)
                    if store.selectedProject?.id == project.id {
                        store.selectedProject = updated
                    }
                    store.addActivity(ActivityItem(
                        icon: "✏️",
                        text: "프로젝트가 수정되었습니다",
                        highlightedText: updated.name,
                        time: "방금 전"
                    ))
                    dismiss()
                }
            }
            .padding(20)
        }
        .frame(width: 420, height: 800)
        .background(Color(hex: "1A1A2E"))
    }

    private func pricingRow(icon: String, label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 52, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}
