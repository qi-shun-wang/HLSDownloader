import Foundation

public struct HLSCache: Model {
    var timestamp: Date?
    var version: String 
    var caches: [HLS] = []
 }
