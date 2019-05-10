import AVKit

class KeyLoader: NSObject, HLSLoader {
    
    weak var asset: AVURLAsset?
    var repository: HLSRepository!
    
    init(asset: AVURLAsset, repository: HLSRepository) {
        self.asset = asset
        self.repository = repository
        super.init()
        asset.resourceLoader.setDelegate(self, queue: .main)
    } 
}

// AVAssetResourceLoaderDelegate
extension KeyLoader {
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        guard let target = loadingRequest.request.url?.absoluteString else {
            return false
        }
        
        if target.hasSuffix(".key") {
            print("[OK]\(target)")
            guard let movpkgPath = resourceLoader.movpkgPath else {
                print("[ERROR] movpkgPath not found")
                return false
            }
            do {
                let hls = try repository.find(movpkgPath: movpkgPath)
                guard let url = hls?.keyLocalUrl  else {
                    print("[ERROR] keyLocalPath not found")
                    return true
                }
                let data = FileManager.default.contents(atPath: url)
                loadingRequest.dataRequest?.respond(with: data!)
                loadingRequest.finishLoading()
                return true
            } catch {
                print("[ERROR] hls not found")
            }
        }
        return true
    }
}
// Helper
extension AVAssetResourceLoader {
    var movpkgPath: String? {
        get {
            return (delegate as? KeyLoader)?.asset?.url.path.replacingOccurrences(of: NSHomeDirectory() + "/", with: "")
        }
    }
}

