//
//  Cell.swift
//  hls-cookie-avplayer
//
//  Created by Shun Wang on 2019/5/9.
//  Copyright © 2019 jetfuel. All rights reserved.
//

import UIKit
import AVKit

class Cell: UITableViewCell {
    
    typealias URLAction = ((String?)->Void)
    typealias CellAction = ((Cell, String?)->Void)
    @IBOutlet weak var progresBar: UIProgressView!
    @IBOutlet weak var playerView: UIView!
    var playerLayer: AVPlayerLayer!
    
    @IBOutlet weak var hlsUrl: UILabel!
    
    var url: String? {
        didSet {
            hlsUrl.text = url
        }
    }
    
    var play: CellAction?
    var pause: CellAction?
    var download: URLAction?
    var suspend: URLAction?
    var delete: URLAction?
    
    @IBAction func playAction(_ sender: UIButton) {
        play?(self, url)
    }
    
    @IBAction func pauseAction(_ sender: UIButton) {
        pause?(self, url)
    }
    
    @IBAction func downloadAction(_ sender: UIButton) {
        download?(url)
    }
    
    @IBAction func suspendAction(_ sender: UIButton) {
        suspend?(url)
    }
    
    @IBAction func deleteAction(_ sender: UIButton) {
        delete?(url)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        playerLayer = AVPlayerLayer()
        playerLayer.frame = playerView.bounds
        playerView.layer.addSublayer(playerLayer)
       
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
