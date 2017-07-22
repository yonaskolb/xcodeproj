import Foundation
import PathKit
import xcodeprojprotocols

public typealias XCConfigInclude = (include: Path, config: XCConfig)

/// .xcconfig configuration file.
public struct XCConfig {
    
    // MARK: - Attributes
    
    /// Configuration file path.
    public let path: Path
    
    /// Configuration file includes.
    public let includes: [XCConfigInclude]
    
    /// Build settings
    public let buildSettings: BuildSettings
    
    // MARK: - Init
    
    /// Initializes the XCConfig file with its attributes.
    ///
    /// - Parameters:
    ///   - path: path where the .xcconfig file is.
    ///   - includes: all the .xcconfig file includes. The order determines how the values get overriden.
    ///   - dictionary: dictionary that contains the config.
    public init(path: Path, includes: [XCConfigInclude], buildSettings: BuildSettings) {
        self.path = path
        self.includes = includes
        self.buildSettings = buildSettings
    }
    
}

// MARK: - XCConfig Extension (Equatable)

extension XCConfig: Equatable {
    
    public static func == (lhs: XCConfig, rhs: XCConfig) -> Bool {
        if lhs.includes.count != rhs.includes.count { return false }
        for i in 0..<lhs.includes.count {
            let lhsInclude = lhs.includes[i]
            let rhsInclude = rhs.includes[i]
            if lhsInclude.config != rhsInclude.config || lhsInclude.include != rhsInclude.include {
                return false
            }
        }
        return lhs.path == rhs.path &&
            lhs.buildSettings == rhs.buildSettings
    }
    
}

// MARK: - XCConfig Extension (Init)

extension XCConfig {
    
    /// Initializes the XCConfig reading the content from the file at the given path and parsing it.
    ///
    /// - Parameter path: path where the .xcconfig file is.
    /// - Throws: an error if the config file cannot be found or it has an invalid format.
    public init(path: Path) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path.string) { throw XCConfigError.notFound(path: path) }
        self.path = path
        let fileContent = try String(contentsOf: path.url)
        let fileLines = fileContent.components(separatedBy: "\n")
        self.includes = fileLines
            .map(XCConfig.configFrom(path: path))
            .filter { $0 != nil }
            .map { $0! }
        var buildSettings: [String: String] = [:]
        fileLines
            .map(XCConfig.settingFrom)
            .filter { $0 != nil }
            .map { $0! }
            .forEach { buildSettings[$0.key] = $0.value }
        self.buildSettings = BuildSettings(dictionary: buildSettings)
    }
    
    /// Given the path the line is being parsed from, it returns a function that parses a line, 
    /// and returns the include path and the config that the include is pointing to.
    ///
    /// - Parameter path: path of the config file that the line belongs to.
    /// - Returns: function that parses the line.
    private static func configFrom(path: Path) -> (String) -> (include: Path, config: XCConfig)? {
        return { line in
            return XCConfig.includeRegex.matches(in: line,
                                                 options: NSRegularExpression.MatchingOptions(rawValue: 0),
                                                 range: NSRange(location: 0,
                                                                length: line.characters.count))
                .flatMap { (match) -> String? in
                    if match.numberOfRanges == 2 {
                        return NSString(string: line).substring(with: match.rangeAt(1))
                    }
                    return nil
                }
                .flatMap { pathString in
                    let includePath: Path = Path(pathString)
                    var config: XCConfig?
                    if includePath.isRelative {
                        config = try? XCConfig(path: path.parent() + includePath)
                    } else {
                        config = try? XCConfig(path: includePath)
                    }
                    return config.map { (includePath, $0) }
                }
                .first
        }
    }
    
    private static func settingFrom(line: String) -> (key: String, value: String)? {
        return XCConfig.settingRegex.matches(in: line,
                                             options: NSRegularExpression.MatchingOptions(rawValue: 0),
                                             range: NSRange(location: 0,
                                                            length: line.characters.count))
            .flatMap { (match) -> (key: String, value: String)?  in
                if match.numberOfRanges == 3 {
                    let key: String = NSString(string: line).substring(with: match.rangeAt(1))
                    let value: String = NSString(string: line).substring(with: match.rangeAt(2))
                    return (key, value)
                }
                return nil
            }
            .first
    }
    
    // swiftlint:disable:next force_try line_length
    private static var includeRegex: NSRegularExpression = try! NSRegularExpression(pattern: "#include\\s+\"(.+\\.xcconfig)\"",
                                                                                    options: .caseInsensitive)
    // swiftlint:disable:next force_try line_length
    private static var settingRegex: NSRegularExpression = try! NSRegularExpression(pattern: "(.+)\\s+=\\s+(\"?.[^\"]+\"?)",
                                                                                    options: .caseInsensitive)
    
}

// MARK: - XCConfig Extension (Helpers)

extension XCConfig {
    
    /// It returns the build settings after flattening all the includes.
    ///
    /// - Returns: build settings flattening all the includes.
    public func flattenedBuildSettings() -> BuildSettings {
        var content: [String: Any] = buildSettings.dictionary
        includes
            .map { $0.1 }
            .flattened()
            .map { $0.buildSettings.dictionary }
            .forEach { (configDictionary) in
                configDictionary.forEach { (key, value) in
                    if content[key] == nil { content[key] = value }
                }
        }
        return BuildSettings(dictionary: content)
    }
    
}

// MARK: - XCConfig Extension (Writable)

extension XCConfig: Writable {
    
    public func write(path: Path, override: Bool) throws {
        var content = ""
        content.append(writeIncludes())
        content.append("\n")
        content.append(writeBuildSettings())
        if override && path.exists {
            try path.delete()
        }
        try path.write(content)
    }
    
    private func writeIncludes() -> String {
        var content = ""
        includes.forEach { (include) in
            content.append("#include \"\(include.0.string)\"\n")
        }
        content.append("\n")
        return content
    }
    
    private func writeBuildSettings() -> String {
        var content = ""
        buildSettings.dictionary.forEach { (key, value) in
            content.append("\(key) = \(value)\n")
        }
        content.append("\n")
        return content
    }
    
}

// MARK: - Array Extension (XCConfig)

extension Array where Element == XCConfig {
    
    /// It returns an array with the XCConfig reversely flattened. It's useful for resolving the build settings.
    ///
    /// - Returns: flattened configurations array.
    func flattened() -> [XCConfig] {
        let reversed = self.reversed()
            .flatMap { (config) -> [XCConfig] in
                var configs = [XCConfig(path: config.path, includes: [], buildSettings: config.buildSettings)]
                configs.append(contentsOf: config.includes.map { $0.1 }.flattened())
                return configs
        }
        return reversed
    }
    
}

// MARK: - XCConfigError

/// XCConfig errors.
///
/// - notFound: returned when the configuration file couldn't be found.
public enum XCConfigError: Error, CustomStringConvertible {
    case notFound(path: Path)
    public var description: String {
        switch self {
        case .notFound(let path):
            return ".xcconfig file not found at \(path)"
        }
    }
}
