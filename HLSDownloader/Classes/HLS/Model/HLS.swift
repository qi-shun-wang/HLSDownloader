import Foundation

public protocol Model: Decodable & Encodable {}

public struct HLS: Model {
    public let uuid: UUID
    public let url: String
    public var movpkgLocalPath: String?
    public var m3u8LocalPath: String?
    public var keyLocalPath: String?
    public var state: String
    public var taskIdentifier: Int?
    
    public enum State: String {
        case pendding
        case downloading
        case suspended
        case missingKey
        case missingM3U8
        case missingTS
        case downloaded
    }
    
}
enum HLSError: Error {
    case invalidState
    case invalidOperation
}
extension HLS: Hashable {}
extension HLS {
    //Full Path
   public  var keyLocalUrl: String? {
        get {
            guard let path = keyLocalPath else {return nil}
            return NSHomeDirectory() + "/" + path
        }
    }
    
    //Full Path
    public var movpkgLocalFileUrl: URL? {
        get {
            guard let path = movpkgLocalPath else {return nil}
            return URL(fileURLWithPath: NSHomeDirectory() + "/" + path)
        }
    }
    //Full Path
    public var movpkgLocalUrl: URL? {
        get {
            guard let path = movpkgLocalPath else {return nil}
            return URL(string: NSHomeDirectory() + "/" + path)
        }
    }
    
    public var bootXMLPath: String? {
        get {
            return movpkgLocalUrl?.appendingPathComponent("boot.xml").path
        }
    }
    
}
