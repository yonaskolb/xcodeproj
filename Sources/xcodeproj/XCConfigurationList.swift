import Foundation
import Unbox

// This is the element for listing build configurations.
public struct XCConfigurationList {
    
    // MARK: - Attributes
    
    /// Element reference.
    public let reference: String
    
    /// Element build configurations.
    public let buildConfigurations: Set<String>
    
    /// Element default configuration is visible.
    public let defaultConfigurationIsVisible: UInt
    
    /// Element default configuration name
    public let defaultConfigurationName: String
    
    // MARK: - Init
    
    /// Initializes the element with its properties.
    ///
    /// - Parameters:
    ///   - reference: element reference.
    ///   - buildConfigurations: element build configurations.
    ///   - defaultConfigurationName: element default configuration name.
    ///   - defaultConfigurationIsVisible: default configuration is visible.
    public init(reference: String,
                buildConfigurations: Set<String>,
                defaultConfigurationName: String,
                defaultConfigurationIsVisible: UInt = 0) {
        self.reference = reference
        self.buildConfigurations = buildConfigurations
        self.defaultConfigurationName = defaultConfigurationName
        self.defaultConfigurationIsVisible = defaultConfigurationIsVisible
    }

}

extension XCConfigurationList {
    
    /// Returns a new configuration list adding a configuration.
    ///
    /// - Parameter configuration: refrence to the configuration to be added.
    /// - Returns: new configuration list with the configuration added.
    public func adding(configuration: String) -> XCConfigurationList {
        var buildConfigurations = self.buildConfigurations
        buildConfigurations.update(with: configuration)
        return XCConfigurationList(reference: self.reference,
                                   buildConfigurations: buildConfigurations,
                                   defaultConfigurationName: self.defaultConfigurationName)
    }
    
    /// Returns a new configuration list removing a configuration.
    ///
    /// - Parameter configuration: reference to the configuration to be removed.
    /// - Returns: new configuration list with the configuration removed.
    public func removing(configuration: String) -> XCConfigurationList {
        var buildConfigurations = self.buildConfigurations
        buildConfigurations.remove(configuration)
        return XCConfigurationList(reference: self.reference,
                                   buildConfigurations: buildConfigurations,
                                   defaultConfigurationName: self.defaultConfigurationName)
        
    }
    
    /// Returns a new XCConfigurationList with a given configuration name.
    ///
    /// - Parameter name: configuration name.
    /// - Returns: new configuration list with the given configuration name.
    public func withDefaultConfigurationName(name: String) -> XCConfigurationList {
        return XCConfigurationList(reference: self.reference,
                                   buildConfigurations: self.buildConfigurations,
                                   defaultConfigurationName: name)
    }
    
}

// MARK: - XCConfigurationList Extension (PlistSerializable)

extension XCConfigurationList: PlistSerializable {
    
    public static var isa: String = "XCConfigurationList"
    
    func plistKeyAndValue(proj: PBXProj) -> (key: CommentedString, value: PlistValue) {
        var dictionary: [CommentedString: PlistValue] = [:]
        dictionary["isa"] = .string(CommentedString(XCConfigurationList.isa))
        dictionary["buildConfigurations"] = .array(buildConfigurations
            .map { .string(CommentedString($0, comment: proj.objects.configName(from: $0)))
        })
        dictionary["defaultConfigurationIsVisible"] = .string(CommentedString("\(defaultConfigurationIsVisible)"))
        dictionary["defaultConfigurationName"] = .string(CommentedString(defaultConfigurationName))
        return (key: CommentedString(self.reference,
                                                 comment: plistComment(proj: proj)),
                value: .dictionary(dictionary))
    }
    
    private func plistComment(proj: PBXProj) -> String? {
        let project = proj.objects.projects.filter { $0.buildConfigurationList == self.reference }.first
        let target = proj.objects.nativeTargets.filter { $0.buildConfigurationList == self.reference }.first
        if project != nil {
            return "Build configuration list for PBXProject"
        } else if let target = target {
            return "Build configuration list for PBXNativeTarget \"\(target.name)\""
        }
        return nil
    }

}

// MARK: - XCConfigurationList Extension (ProjectElement)

extension XCConfigurationList: ProjectElement {
    
    public static func == (lhs: XCConfigurationList,
                           rhs: XCConfigurationList) -> Bool {
        return lhs.reference == rhs.reference &&
            lhs.buildConfigurations == rhs.buildConfigurations &&
            lhs.defaultConfigurationIsVisible == rhs.defaultConfigurationIsVisible
    }
    
    public var hashValue: Int { return self.reference.hashValue }
    
    public init(reference: String, dictionary: [String : Any]) throws {
        self.reference = reference
        let unboxer = Unboxer(dictionary: dictionary)
        self.buildConfigurations = try unboxer.unbox(key: "buildConfigurations")
        self.defaultConfigurationIsVisible = try unboxer.unbox(key: "defaultConfigurationIsVisible")
        self.defaultConfigurationName = try unboxer.unbox(key: "defaultConfigurationName")
    }
    
}
