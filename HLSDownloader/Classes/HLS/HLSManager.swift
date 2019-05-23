import AVKit

public protocol HLSManagerDelegate {
    func progress(hls: HLS, percentage: Float)
    func keyWillDownload(hls: HLS)
    func assetDidDownload(hls: HLS)
    func keyDidDownload(hls: HLS)
    
    func didRemove(hls: HLS)
    func didSuspend(hls: HLS)
    func didRestore(hls: HLS)
    func didDownload(hls: HLS)
    func fail(on hls: HLS, with error: HLSManagerError)
}
public enum HLSManagerError: Error {
    case unknownRemoveFailReason
    case unknownSuspendFailReason
    case unknownDownloadFailReason
    case unknownRestoreFailReason
}

public protocol HLSManager: AVAssetDownloadDelegate {
    var loader: HLSLoader? {get set}
    var delegate: HLSManagerDelegate? {get set}
    
    func currentCaches() throws -> HLSCache
    func createHLS(_ url: String) throws -> HLS
    func isExist(_ url: String) throws -> (Bool, HLS?)
    
    func download(_ hls: HLS) throws
    func suspend(_ hls: HLS) throws
    func remove(_ hls: HLS) throws
    
    func getLocalAsset(_ hls: HLS) -> AVPlayerItem?
    
    func restore(_ hls: HLS) throws
    func restoreAll() throws
    
}


public class DownloadHLSManager: NSObject, HLSManager {
    
    public var delegate: HLSManagerDelegate?
    
    private var config: URLSessionConfiguration!
    
    private lazy var downloadSession: AVAssetDownloadURLSession = {
        config = URLSessionConfiguration.background(withIdentifier: "DownloadHLSManagerBackground")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        return AVAssetDownloadURLSession(configuration: config,
                                         assetDownloadDelegate: self,
                                         delegateQueue: .main)
    }()
    private var repository: HLSRepository
    
    public override init() {
        self.repository = try! LocalHLSRepository(folderPath: NSHomeDirectory() + "/Library/Caches")
    }
    
    public var loader: HLSLoader?
    
    public func currentCaches() throws -> HLSCache {
        return try repository.queryHLSCache()
    }
    
    public func suspend(_ hls: HLS) throws {
        print("[Suspend HLS]\(hls.url)")
        downloadSession.getAllTasks { (tasks) in
            let target = tasks.first(where: { (task) -> Bool in
                let taskAssetUrl = (task as! AVAssetDownloadTask).urlAsset.url.absoluteString
                return taskAssetUrl == hls.url
            })
            
            if let task = target {
                print("[Suspend Task]\(hls.url)")
                task.suspend()
                self.delegate?.didSuspend(hls: hls)
            } else {
                self.delegate?.fail(on: hls, with: .unknownSuspendFailReason)
            }
        }
    }
    
    public func remove(_ hls: HLS) throws {
        print("[Remove HLS]\(hls.url)")
        guard let state = HLS.State(rawValue: hls.state) else {throw HLSError.invalidState}
        switch state {
        case .downloaded:
            do {
                try repository.delete(hls: hls)
                delegate?.didRemove(hls: hls)
            } catch {
                delegate?.fail(on: hls, with: .unknownRemoveFailReason)
            }
        default:
            downloadSession.getAllTasks { (tasks) in
                let target = tasks.first(where: { (task) -> Bool in
                    let taskAssetUrl = (task as! AVAssetDownloadTask).urlAsset.url.absoluteString
                    return taskAssetUrl == hls.url
                })
                
                if let task = target {
                    print("[Cancel Task]\(hls.url)")
                    task.cancel()
                    self.delegate?.didRemove(hls: hls)
                } else {
                    self.delegate?.fail(on: hls, with: .unknownRemoveFailReason)
                }
            }
        }
    }
    
    public func restore(_ hls: HLS) throws {
        print("[Restore HLS]\(hls.url)")
        downloadSession.getAllTasks { (tasks) in
            let target = tasks.first(where: { (task) -> Bool in
                let taskAssetUrl = (task as! AVAssetDownloadTask).urlAsset.url.absoluteString
                return taskAssetUrl == hls.url
            })
            
            if let task = target {
                print("[Cancel Task]\(hls.url)")
                task.resume()
                self.delegate?.didRestore(hls: hls)
            } else {
                do {
                    print("[Recovering]\(hls)")
                    try self.repository.delete(hls: hls)
                    try self.download(hls)
                } catch {
                    self.delegate?.fail(on: hls, with: .unknownRestoreFailReason)
                }
            }
        }
    }
    public func restoreAll() {
        
        downloadSession.getAllTasks { (tasks) in
            for task in tasks {
                guard let downloadTask = task as? AVAssetDownloadTask else { break }
                print("[Restoring]\(downloadTask)")
                downloadTask.resume()
            }
        }
    }
    
    public func isExist(_ url: String) throws -> (Bool, HLS?) {
        let cache = try repository.queryHLSCache()
        if let found = cache.caches.first(where: {$0.url == url}) {
            return (true, found)
        }
        else {
            return (false, nil)
        }
    }
    
    
    public func createHLS(_ url: String) throws -> HLS {
        let hls = HLS(uuid: UUID(),
                      url: url,
                      movpkgLocalPath: nil,
                      m3u8LocalPath: nil,
                      keyLocalPath: nil,
                      state: HLS.State.pendding.rawValue,
                      taskIdentifier: nil)
        
        return try repository.create(hls: hls)
    }
    
    public func getLocalAsset(_ hls: HLS) -> AVPlayerItem? {
        guard let url = hls.movpkgLocalFileUrl else {return nil}
        let asset = AVURLAsset(url: url)
        loader = KeyLoader(asset: asset, repository: repository)
        asset.resourceLoader.setDelegate(loader, queue: .main)
        return AVPlayerItem(asset: asset)
    }
    
    // Warring: You must create hls entity before call this download function.
    public func download(_ hls: HLS) throws {
        print("[Download HLS]\(hls.url)")
        var new = hls
        new.state = HLS.State.downloading.rawValue
        try repository.update(hls: new)
        
        let asset = AVURLAsset(url: URL(string: new.url)!, options: nil)
        let task = downloadSession.makeAssetDownloadTask(asset: asset,
                                                         assetTitle: new.uuid.uuidString,
                                                         assetArtworkData: nil,
                                                         options: nil)
        
        
        task?.resume()
        
    }
}

enum DownloadHLSManagerError: Error {
    case isExist
}


// AVAssetDownloadDelegate
extension DownloadHLSManager {
    
    func getHLS(from assetDownloadTask: AVAssetDownloadTask) -> HLS? {
        do {
            guard let hls = try repository.find(url: assetDownloadTask.urlAsset.url.absoluteString) else {return nil}
            return hls
        } catch {
            print("[ERROR]Not found: <\(assetDownloadTask.urlAsset.url.absoluteString)>")
            return nil
        }
    }
    
    public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        var percentComplete = 0.0
        
        for value in loadedTimeRanges {
            
            let loadedTimeRange = value.timeRangeValue
            
            percentComplete += loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
        guard let hls = getHLS(from: assetDownloadTask) else {return}
        DispatchQueue.main.async {
            self.delegate?.progress(hls: hls, percentage: Float(percentComplete))
            print("[Progress] \(assetDownloadTask) \(percentComplete)" )
        }
    }
    
    public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        print("[Asset Location]" + location.absoluteString)
        do {
            guard var hls = try repository.find(url: assetDownloadTask.urlAsset.url.absoluteString) else {return}
            hls.movpkgLocalPath = location.relativePath
            hls.state = HLS.State.missingKey.rawValue
            try repository.update(hls: hls)
            DispatchQueue.main.async {
                self.delegate?.assetDidDownload(hls: hls)
            }
            
        } catch {
            print("[ERROR]Not found: \(assetDownloadTask.urlAsset.url.absoluteString)")
        }
    }
    
}
// URLSessionTaskDelegate
extension DownloadHLSManager {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        guard error == nil else {
            debugPrint("Task completed: \(task), error: \(String(describing: error))")
            return
        }
        if let downloadTask = (task as? AVAssetDownloadTask) {
            print("[DOWNLOAD TASK FINISHED]" + (task.taskDescription ?? ""))
            guard var hls = getHLS(from: downloadTask) else { return}
            do {
                hls.state = HLS.State.missingKey.rawValue
                print("[DOWNLOADED ASSET URL]" + downloadTask.urlAsset.url.absoluteString)
                print("[KEY LOADER]")
                guard let url = hls.movpkgLocalUrl else {return}
                guard let bootXML = hls.bootXMLPath else {return}
                if FileManager.default.fileExists(atPath: bootXML) {
                    var fileContent = try String.init(contentsOf: URL.init(fileURLWithPath: bootXML))
                    fileContent = fileContent.replacingOccurrences(of: "https:", with: "fakehttps:")
                    try fileContent.write(toFile: bootXML, atomically: true, encoding: .utf8)
                }
                
                do {
                    let subDirectories = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants)
                    for url in  subDirectories {
                        print("[Searched]\(url)")
                        var isDirectory: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                            let regex = try NSRegularExpression(pattern:  "URI=\"(.+?)\"")
                            if isDirectory.boolValue {
                                let path = url.path as NSString
                                let folderName = path.lastPathComponent
                                let keyFilePath = "download.key"
                                
                                if folderName == "Data" {
                                    let master = try FileManager.default.contentsOfDirectory(atPath: url.path)[0]
                                    let masterPath = path.appendingPathComponent(master)
                                    var fileContent = try String.init(contentsOf: URL.init(fileURLWithPath: masterPath))
                                    let nsString = fileContent as NSString
                                    let results = regex.matches(in: fileContent, range: NSRange(location: 0, length: nsString.length))
                                    let stringArray = results.map { nsString.substring(with: $0.range)}
                                    for pattern in stringArray {
                                        fileContent = fileContent.replacingOccurrences(of: pattern, with: "URI=\"\(keyFilePath)\"")
                                    }
                                    
                                    try fileContent.write(toFile: masterPath, atomically: true, encoding: .utf8)
                                }
                                
                                let playlistFilePath = path.appendingPathComponent("\(folderName).m3u8")
                                if FileManager.default.fileExists(atPath: path.appendingPathComponent("\(folderName).m3u8")) {
                                    
                                    print("[Searched]\(playlistFilePath)")
                                    var fileContent = try String.init(contentsOf: URL.init(fileURLWithPath: playlistFilePath))
                                    
                                    let nsString = fileContent as NSString
                                    let results = regex.matches(in: fileContent, range: NSRange(location: 0, length: nsString.length))
                                    let stringArray = results.map { nsString.substring(with: $0.range)}
                                    
                                    let m3u8LocalPath = "Library\((path.components(separatedBy: "Library").last ?? ""))/\(folderName).m3u8"
                                    let keyLocalPath = "Library\((path.components(separatedBy: "Library").last ?? ""))/\(keyFilePath)"
                                    
                                    for pattern in stringArray {
                                        DispatchQueue.global(qos: .background).sync {
                                            let remote_key = pattern.replacingOccurrences(of: "URI=", with: "").trimmingCharacters(in: CharacterSet.init(charactersIn: "\""))
                                            DispatchQueue.main.async {
                                                self.delegate?.keyWillDownload(hls: hls)
                                            }
                                            URLSession.shared.dataTask(with: URL(string: remote_key)!, completionHandler: { (data, res, err) in
                                                if let data = data {
                                                    let keypath = URL(fileURLWithPath: NSHomeDirectory() + "/" + keyLocalPath)
                                                    //                                                    DispatchQueue.main.async {
                                                    do {
                                                        try data.write(to: keypath)
                                                        try fileContent.write(toFile: playlistFilePath, atomically: true, encoding: .utf8)
                                                        print("[Key Fetched Sucess]")
                                                        print("[Update Key Path] \(keyLocalPath)")
                                                        hls.keyLocalPath = keyLocalPath
                                                        hls.m3u8LocalPath = m3u8LocalPath
                                                        hls.state = HLS.State.downloaded.rawValue
                                                        
                                                        try self.repository.update(hls: hls)
                                                        
                                                        DispatchQueue.main.async {
                                                            self.delegate?.keyDidDownload(hls: hls)
                                                        }
                                                    }
                                                    catch {
                                                        print("[Key Fetched Fail]")
                                                    }
                                                    //                                                    }
                                                } else {
                                                    print("[Key Fetched Fail]")
                                                }
                                            }).resume()
                                        }
                                        fileContent = fileContent.replacingOccurrences(of: pattern, with: "URI=\"\(keyFilePath)\"")
                                    }
                                }
                                let streamInfoBoot = path.appendingPathComponent("StreamInfoBoot.xml")
                                if FileManager.default.fileExists(atPath: streamInfoBoot) {
                                    var fileContent = try String.init(contentsOf: URL.init(fileURLWithPath: streamInfoBoot))
                                    fileContent = fileContent.replacingOccurrences(of: "https:", with: "fakehttps:")
                                    try fileContent.write(toFile: streamInfoBoot, atomically: true, encoding: .utf8)
                                }
                            }
                        }
                    }
                }
                catch {
                    print("Cannot list directory")
                    
                }
                
            } catch {
                
            }
        } else {
            
            print("[OTHER TASK FINISHED]" + (task.taskDescription ?? ""))
        }
        
    }
}
