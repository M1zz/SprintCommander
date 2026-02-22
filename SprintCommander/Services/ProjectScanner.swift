import Foundation

class ProjectScanner {

    struct ScanResult {
        let projectName: String
        let projectType: String       // "Xcode Project", "Swift Package" etc.
        let language: String           // "Swift", "JavaScript" etc.
        let framework: String          // "SwiftUI", "UIKit", "React" etc.
        let totalFiles: Int
        let totalLines: Int
        let icon: String               // auto-recommended emoji
        let desc: String               // auto-generated description
        let version: String            // detected version (e.g. "1.0", "2.3.1")
    }

    // MARK: - Directories to exclude from scanning

    private static let excludedDirectories: Set<String> = [
        "DerivedData", ".build", "Pods", "node_modules", ".git",
        "xcuserdata", "build", ".swiftpm", "Carthage", ".next",
        "dist", "__pycache__", ".venv", "venv", "target"
    ]

    // MARK: - File extensions per language

    private static let swiftExtensions: Set<String> = ["swift"]
    private static let jsExtensions: Set<String> = ["js", "jsx", "ts", "tsx"]
    private static let pythonExtensions: Set<String> = ["py"]
    private static let rustExtensions: Set<String> = ["rs"]
    private static let goExtensions: Set<String> = ["go"]
    private static let cppExtensions: Set<String> = ["c", "cpp", "h", "hpp", "m", "mm"]

    private static let allCodeExtensions: Set<String> = {
        var all = Set<String>()
        all.formUnion(swiftExtensions)
        all.formUnion(jsExtensions)
        all.formUnion(pythonExtensions)
        all.formUnion(rustExtensions)
        all.formUnion(goExtensions)
        all.formUnion(cppExtensions)
        return all
    }()

    // MARK: - Public API

    func scan(path: String) async -> ScanResult? {
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }

        let projectType = detectProjectType(at: url)
        let projectName = detectProjectName(at: url, type: projectType)
        let (files, fileCounts, totalLines) = analyzeStructure(at: url)
        let language = detectLanguage(fileCounts: fileCounts)
        let framework = detectFramework(files: files, language: language)
        let icon = recommendIcon(type: projectType, framework: framework)
        let desc = generateDescription(framework: framework, type: projectType, fileCount: files.count)
        let version = detectVersion(at: url, type: projectType)

        return ScanResult(
            projectName: projectName,
            projectType: projectType,
            language: language,
            framework: framework,
            totalFiles: files.count,
            totalLines: totalLines,
            icon: icon,
            desc: desc,
            version: version
        )
    }

    // MARK: - Project Type Detection

    private func detectProjectType(at url: URL) -> String {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: url.path) else {
            return "Unknown"
        }

        if contents.contains(where: { $0.hasSuffix(".xcworkspace") }) {
            return "Xcode Workspace"
        }
        if contents.contains(where: { $0.hasSuffix(".xcodeproj") }) {
            return "Xcode Project"
        }
        if contents.contains("Package.swift") {
            return "Swift Package"
        }
        if contents.contains("package.json") {
            return "Node.js Project"
        }
        if contents.contains("Cargo.toml") {
            return "Rust Project"
        }
        if contents.contains("go.mod") {
            return "Go Module"
        }
        if contents.contains("requirements.txt") || contents.contains("setup.py") || contents.contains("pyproject.toml") {
            return "Python Project"
        }
        if contents.contains("CMakeLists.txt") || contents.contains("Makefile") {
            return "C/C++ Project"
        }

        return "Unknown"
    }

    // MARK: - Project Name Detection

    private func detectProjectName(at url: URL, type: String) -> String {
        let fm = FileManager.default

        // Try to extract name from .xcodeproj or .xcworkspace
        if type == "Xcode Project" || type == "Xcode Workspace" {
            if let contents = try? fm.contentsOfDirectory(atPath: url.path) {
                if let proj = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
                    return (proj as NSString).deletingPathExtension
                }
                if let ws = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
                    return (ws as NSString).deletingPathExtension
                }
            }
        }

        // Fallback: use directory name
        return url.lastPathComponent
    }

    // MARK: - Structure Analysis

    private func analyzeStructure(at url: URL) -> (files: [URL], fileCounts: [String: Int], totalLines: Int) {
        let fm = FileManager.default
        var codeFiles: [URL] = []
        var fileCounts: [String: Int] = [:]
        var totalLines = 0

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ([], [:], 0)
        }

        for case let fileURL as URL in enumerator {
            // Skip excluded directories
            if Self.excludedDirectories.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            guard Self.allCodeExtensions.contains(ext) else { continue }

            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else { continue }

            codeFiles.append(fileURL)
            fileCounts[ext, default: 0] += 1

            // Count lines
            if let data = try? Data(contentsOf: fileURL),
               let content = String(data: data, encoding: .utf8) {
                totalLines += content.components(separatedBy: .newlines).count
            }
        }

        return (codeFiles, fileCounts, totalLines)
    }

    // MARK: - Language Detection

    private func detectLanguage(fileCounts: [String: Int]) -> String {
        var langScores: [String: Int] = [:]

        for (ext, count) in fileCounts {
            if Self.swiftExtensions.contains(ext) {
                langScores["Swift", default: 0] += count
            } else if Self.jsExtensions.contains(ext) {
                langScores["JavaScript", default: 0] += count
            } else if Self.pythonExtensions.contains(ext) {
                langScores["Python", default: 0] += count
            } else if Self.rustExtensions.contains(ext) {
                langScores["Rust", default: 0] += count
            } else if Self.goExtensions.contains(ext) {
                langScores["Go", default: 0] += count
            } else if Self.cppExtensions.contains(ext) {
                langScores["C/C++", default: 0] += count
            }
        }

        return langScores.max(by: { $0.value < $1.value })?.key ?? "Unknown"
    }

    // MARK: - Framework Detection (sampling imports)

    private func detectFramework(files: [URL], language: String) -> String {
        // Sample up to 30 files for import analysis
        let sampled = files.prefix(30)
        var importCounts: [String: Int] = [:]

        for fileURL in sampled {
            guard let data = try? Data(contentsOf: fileURL),
                  let content = String(data: data, encoding: .utf8) else { continue }

            let lines = content.components(separatedBy: .newlines)
            for line in lines.prefix(50) { // only scan top 50 lines per file
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Swift imports
                if trimmed.hasPrefix("import ") {
                    let module = trimmed.replacingOccurrences(of: "import ", with: "").trimmingCharacters(in: .whitespaces)
                    if module == "SwiftUI" { importCounts["SwiftUI", default: 0] += 1 }
                    else if module == "UIKit" { importCounts["UIKit", default: 0] += 1 }
                    else if module == "AppKit" { importCounts["AppKit", default: 0] += 1 }
                    else if module == "Vapor" { importCounts["Vapor", default: 0] += 1 }
                }

                // JS/TS imports
                if trimmed.contains("from 'react'") || trimmed.contains("from \"react\"") {
                    importCounts["React", default: 0] += 1
                }
                if trimmed.contains("from 'vue'") || trimmed.contains("from \"vue\"") {
                    importCounts["Vue", default: 0] += 1
                }
                if trimmed.contains("@angular") {
                    importCounts["Angular", default: 0] += 1
                }
                if trimmed.contains("from 'next") || trimmed.contains("from \"next") {
                    importCounts["Next.js", default: 0] += 1
                }
            }
        }

        return importCounts.max(by: { $0.value < $1.value })?.key ?? language
    }

    // MARK: - Icon Recommendation

    private func recommendIcon(type: String, framework: String) -> String {
        switch framework {
        case "SwiftUI", "UIKit":
            return "📱"
        case "AppKit":
            return "🖥️"
        case "React", "Vue", "Angular", "Next.js":
            return "🌐"
        case "Vapor":
            return "🔧"
        default:
            break
        }

        switch type {
        case "Xcode Project", "Xcode Workspace":
            return "📱"
        case "Swift Package":
            return "📦"
        case "Node.js Project":
            return "🌐"
        case "Rust Project":
            return "🔧"
        case "Go Module":
            return "🔧"
        case "Python Project":
            return "🐍"
        case "C/C++ Project":
            return "🔧"
        default:
            return "📁"
        }
    }

    // MARK: - Version Detection

    private func detectVersion(at url: URL, type: String) -> String {
        let fm = FileManager.default

        // Xcode project: read MARKETING_VERSION from pbxproj
        if type == "Xcode Project" || type == "Xcode Workspace" {
            if let contents = try? fm.contentsOfDirectory(atPath: url.path),
               let proj = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
                let pbxpath = url.appendingPathComponent(proj).appendingPathComponent("project.pbxproj").path
                if let data = fm.contents(atPath: pbxpath),
                   let text = String(data: data, encoding: .utf8) {
                    // Find MARKETING_VERSION = "x.y.z"; or MARKETING_VERSION = x.y;
                    let pattern = #"MARKETING_VERSION\s*=\s*"?([^";]+)"?\s*;"#
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                       let range = Range(match.range(at: 1), in: text) {
                        return String(text[range]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        // Swift Package: no standard version field, skip

        // Node.js: package.json → "version"
        let packageJsonPath = url.appendingPathComponent("package.json").path
        if let data = fm.contents(atPath: packageJsonPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ver = json["version"] as? String {
            return ver
        }

        // Rust: Cargo.toml → version = "x.y.z"
        let cargoPath = url.appendingPathComponent("Cargo.toml").path
        if let data = fm.contents(atPath: cargoPath),
           let text = String(data: data, encoding: .utf8) {
            let pattern = #"^\s*version\s*=\s*"([^"]+)""#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        // Python: pyproject.toml → version = "x.y.z"
        let pyprojectPath = url.appendingPathComponent("pyproject.toml").path
        if let data = fm.contents(atPath: pyprojectPath),
           let text = String(data: data, encoding: .utf8) {
            let pattern = #"^\s*version\s*=\s*"([^"]+)""#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        // Go: no standard version field
        return ""
    }

    // MARK: - Description Generation

    private func generateDescription(framework: String, type: String, fileCount: Int) -> String {
        let base: String
        if framework != "Unknown" && framework != type {
            base = "\(framework) 기반 \(type)"
        } else {
            base = type
        }
        return "\(base) · \(fileCount)개 파일"
    }
}
