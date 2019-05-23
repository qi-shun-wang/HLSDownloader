//
//  ViewController.swift
//  HLSDownloader
//
//  Created by qi-shun-wang on 05/10/2019.
//  Copyright (c) 2019 qi-shun-wang. All rights reserved.
//

import UIKit
import AVKit
import HLSDownloader

class ViewController: UIViewController, HLSAccessible {
    
    let urls = [
        "https://xxxxx1.m3u8",
        "https://xxxxx2.m3u8",
        "https://xxxxx3.m3u8"
    ]
    let sessionName = "sessionName"
    let sessionValue = "sessionValue"
    let seesionDomain = "seesionDomain"
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var hlsContent: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCookie()
        manager.delegate = self
        updateHLSContent(text: String(describing: try? manager.currentCaches()))
    }
}

extension ViewController {
    func setupCookie() {
        HTTPCookieStorage.shared.setCookie(HTTPCookie(properties: [
            HTTPCookiePropertyKey.name : sessionName,
            HTTPCookiePropertyKey.value: sessionValue,
            HTTPCookiePropertyKey.path:"/",
            HTTPCookiePropertyKey.domain: seesionDomain
            
            ])!)
    }
    // UI
    func updateHLSContent(text: String) {
        hlsContent.text = text
    }
}


extension ViewController: HLSManagerDelegate {
    func keyWillDownload(hls: HLS) {
        print("[Key Downloading]")
    }
    
    func assetDidDownload(hls: HLS) {
        print("[Asset Downloaded]")
    }
    
    func keyDidDownload(hls: HLS) {
        print("[Key Downloaded]")
    }
    
    func didRemove(hls: HLS) {
        print("[Removed]")
    }
    
    func didSuspend(hls: HLS) {
        print("[Suspended]")
    }
    
    func didRestore(hls: HLS) {
        print("[Restored]")
    }
    
    func didDownload(hls: HLS) {
        print("[Downloaded]")
    }
    
    func fail(on hls: HLS, with error: HLSManagerError) {
        print("[Fail]")
        print(hls)
        print(error)
    }
    
    
    public func progress(hls: HLS, percentage: Float) {
        guard let index = urls.firstIndex(of: hls.url) else {return}
        let cellIndexPath = IndexPath(row: index, section: 0)
        let cell = (tableView.cellForRow(at: cellIndexPath) as? Cell)
        cell?.progresBar.progress = percentage
    }
    
}



extension ViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! Cell
        let url = urls[indexPath.row]
        cell.url = url
        cell.download = download
        cell.suspend = suspend
        cell.play = play
        cell.pause = pause
        cell.delete = delete
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return urls.count
    }
    
    func play(_ cell: Cell, _ url: String?) {
        if check(url: url) {
            do {
                let (isExist, hls) = try manager.isExist(url!)
                if isExist {
                    print("[HLS Exist]\(url!)")
                    
                    if HLS.State(rawValue: hls!.state) == .downloaded {
                        if cell.playerLayer.player == nil {
                            let item = manager.getLocalAsset(hls!)
                            let player = AVPlayer(playerItem: item)
                            cell.playerLayer.player = player
                        }
                        cell.playerLayer.player?.play()
                    }
                    else {
                        print("[HLS Not Downloaded]\(url!)")
                    }
                }
                else {
                    print("[HLS Not Exist]\(url!)")
                }
            } catch {
                print("[ERROR]Repository problem")
            }
        }
        
    }
    
    func pause(_ cell: Cell, _ url: String?) {
        if check(url: url) {
            cell.playerLayer.player?.pause()
        }
    }
    
    func delete( _ url: String?) {
        if check(url: url) {
            do {
                let (isExist, hls) = try manager.isExist(url!)
                if isExist {
                    print("[URL is exist] \(url!)")
                    try manager.remove(hls!)
                }
                else {
                    print("[URL is not exist] \(url!)")
                }
            }
            catch let err {
                print(err)
            }
        }
    }
    
    func suspend( _ url: String?) {
        if check(url: url) {
            do {
                let (isExist, hls) = try manager.isExist(url!)
                if isExist {
                    print("[URL is exist] \(url!)")
                    try manager.suspend(hls!)
                }
                else {
                    print("[URL is not exist] \(url!)")
                }
            }
            catch let err {
                print(err)
            }
        }
    }
    
    func download(_ url: String?) {
        if check(url: url) {
            do {
                let (isExist, hls) = try manager.isExist(url!)
                if isExist {
                    print("[URL is exist] \(url!)")
                    try manager.restore(hls!)
                } else {
                    print("[URL is not exist] \(url!)")
                    let hls = try manager.createHLS(url!)
                    try manager.download(hls)
                }
            }
            catch let err {
                print(err)
            }
        }
    }
    
    private func check(url: String?) -> Bool {
        return urls.contains(url ?? "")
    }
}
