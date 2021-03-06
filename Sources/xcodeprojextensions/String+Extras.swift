import Foundation

extension String {
    
    public var quoted: String {
        return "\"\(self)\""
    }

    public var isQuoted: Bool {
        return hasPrefix("\"") && hasSuffix("\"")
    }
    
    public static func random(length: Int = 20) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""
        
        for _ in 0..<length {
            let randomValue = arc4random_uniform(UInt32(base.characters.count))
            randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
        }
        return randomString
    }
    
}
