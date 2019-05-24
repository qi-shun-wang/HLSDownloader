import Foundation

public protocol HLSRepository {
    func queryHLSCache() throws -> HLSCache
    func create(hls: HLS) throws -> HLS
    func update(hls: HLS) throws
    func find(uuid: UUID) throws -> HLS?
    func find(taskID: Int) throws -> HLS?
    func find(movpkgPath: String) throws -> HLS?
    func find(url: String) throws -> HLS?
    func delete(hls: HLS) throws
}

public class LocalHLSRepository {
    
    let folderPath: String
    let filePath: String
    let dateFormatter = DateFormatter()
    let queue = DispatchQueue(label: "hls.json.queue", attributes: .concurrent)
    
    public init(folderPath: String) throws {
        self.folderPath = folderPath
        self.filePath = folderPath + "/hls.json"
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        if FileManager.default.fileExists(atPath: folderPath + "/hls.json") {
            print("[LocalHLSRepository] Exist")
            guard let content = FileManager.default.contents(atPath: filePath)
                else {throw NSError(domain: "LocalHLSRepository", code: NSFileWriteNoPermissionError, userInfo: nil)}
            // TODO : data migration
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            let cache = try decoder.decode(HLSCache.self, from: content)
            print("[LocalHLSRepository Content] At \(filePath)")
            print(cache)
            print("[LocalHLSRepository EOF]")
            
        } else {
            print("[LocalHLSRepository] Not Exist")
            print("[LocalHLSRepository] Creating")
            
            let cache = HLSCache(timestamp: Date(), version: "0.3.0", caches: [])
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            let initData = try encoder.encode(cache)
            
            if FileManager.default.createFile(atPath: filePath, contents: initData, attributes: nil) {
                print("[LocalHLSRepository] Created")
                print("[LocalHLSRepository Content]At \(filePath)")
                do {
                    let content = try String(contentsOfFile: filePath, encoding: .utf8)
                    print("[LocalHLSRepository Content]At \(filePath)")
                    print(content)
                    print("[LocalHLSRepository EOF]")
                } catch let err {
                    print("[LocalHLSRepository]Can't read file.")
                    print(err)
                }
                
            } else {
                throw NSError(domain: "LocalHLSRepository", code: NSFileWriteNoPermissionError, userInfo: nil)
            }
            
        }
    }
}


extension LocalHLSRepository: HLSRepository {
    
    public func queryHLSCache() throws -> HLSCache {
        return try queue.sync {
            guard let content = FileManager.default.contents(atPath: filePath)
                else {throw NSError(domain: "LocalHLSRepository", code: NSFileWriteNoPermissionError, userInfo: nil)}
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            return try decoder.decode(HLSCache.self, from: content)
        }
    }
    
    public func delete(hls: HLS) throws {
        var cache = try queryHLSCache()
        if let index = cache.caches.lastIndex(where: { ($0.uuid == hls.uuid) }) {
            cache.caches.remove(at: index)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            let new = try encoder.encode(cache)
            let url = URL(fileURLWithPath: filePath)
            try new.write(to: url)
        }
        // Warning: movpkgLocalFileUrl location is possible be nil before completed download task.
        guard let movpkgPath = hls.movpkgLocalFileUrl else {return}
        try FileManager.default.removeItem(at: movpkgPath)
        
    }
    
    public func create(hls: HLS) throws -> HLS {
        var cache = try queryHLSCache()
        if let old = cache.caches.first(where: { $0.url == hls.url }) {
            return old
        } else {
            cache.caches.append(hls)
            cache.timestamp = Date()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            let new = try encoder.encode(cache)
            let url = URL(fileURLWithPath: filePath)
            return try queue.sync {
                try new.write(to: url)
                return hls
            }
        }
    }
    
    public func update(hls: HLS) throws {
        var cache = try queryHLSCache()
        if let index = cache.caches.lastIndex(where: { ($0.uuid == hls.uuid) }) {
            cache.caches[index] = hls
            cache.timestamp = Date()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            let new = try encoder.encode(cache)
            let url = URL(fileURLWithPath: filePath)
            try new.write(to: url)
        }
    }
    public func find(taskID: Int) throws -> HLS? {
        return try queryHLSCache().caches.first(where: { ($0.taskIdentifier == taskID) })
    }
    public func find(uuid: UUID) throws -> HLS? {
        return try queryHLSCache().caches.first(where: { ($0.uuid == uuid) })
    }
    public func find(movpkgPath: String) throws -> HLS? {
        return try queryHLSCache().caches.first(where: { ($0.movpkgLocalPath == movpkgPath) })
    }
    
    public func find(url: String) throws -> HLS? {
        return try queryHLSCache().caches.first(where: { ($0.url == url) })
    }
}
