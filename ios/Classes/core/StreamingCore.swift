//
//  StreamingCore.swift
//  flutter_radio_player
//
//  Created by Sithira on 3/26/20.
//

import Foundation
import AVFoundation
import MediaPlayer

var timer: Timer = Timer()
class StreamingCore : NSObject, AVPlayerItemMetadataOutputPushDelegate {

    private var avPlayer: AVPlayer?
    private var avPlayerItem: AVPlayerItem?
    private var playerItemContext = 0
    private var commandCenter: MPRemoteCommandCenter?
    private var playWhenReady: Bool = false
    private var streamLink: String = ""

    override init() {
        print("StreamingCore Initializing...")
    }

    func initService(streamURL: String, serviceName: String, secondTitle: String, playWhenReady: String) -> Void {

        print("Initialing Service...")

        print("Stream url: " + streamURL)
        streamLink = streamURL

        let streamURLInstance = URL(string: streamURL)

        // Setting up AVPlayer
        avPlayerItem = AVPlayerItem(url: streamURLInstance!)
        avPlayer = AVPlayer(playerItem: avPlayerItem!)

        //Listener for metadata from streaming
        let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metadataOutput.setDelegate(self, queue: DispatchQueue.main)
        avPlayerItem?.add(metadataOutput)

        if playWhenReady == "true" {
            print("PlayWhenReady: true")
            self.playWhenReady = true
        }

        // initialize player observers
        initPlayerObservers()

        // init Remote protocols.
        initRemoteTransportControl(appName: serviceName, subTitle: secondTitle);
    }

    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], from track: AVPlayerItemTrack?) {
      if let item = groups.first?.items.first // make this an AVMetadata item
      {
        item.value(forKeyPath: "value")
        var song: String = (item.value(forKeyPath: "value")!) as! String
        pushEvent(typeEvent: "meta_data", eventName: song)
        if song != "Airtime - offline" {
            let regex2 = try! NSRegularExpression(pattern: "[0-9]", options: [])
            if let separatorIndex = song.lastIndex(of: ".") {
                var songTitle = String(song[..<separatorIndex]);
                if let range = songTitle.range(of: " - ", options: .regularExpression) {
                    songTitle = songTitle.replacingCharacters(in: range, with: "")
                }
                let finalString = regex2.stringByReplacingMatches(in: songTitle, options: [], range: NSMakeRange(0, songTitle.count), withTemplate: "")
                MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtist] = finalString;
            } else {
                if let range = song.range(of: " - ", options: .regularExpression) {
                    song = song.replacingCharacters(in: range, with: "")
                }
                let finalString = regex2.stringByReplacingMatches(in: song, options: [], range: NSMakeRange(0, song.count), withTemplate: "")
                MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtist] = finalString;
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtist] = "";
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] = "Almalak radio";
      }
    }

    func play(duration: Double = -1) -> PlayerStatus {
        print("invoking play method on service")
        if(!isPlaying()) {
            if(duration == -1 ) {
                timer.invalidate()
            } else if (duration != -1) {
                timer = Timer()
                timer = Timer.scheduledTimer(timeInterval: duration * 60, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
            }
            avPlayer?.play()
            pushEvent(eventName: Constants.FLUTTER_RADIO_PLAYING)
        }

        return PlayerStatus.PLAYING
    }

    func pause() -> PlayerStatus {
        print("invoking pause method on service")
        if (isPlaying()) {
            timer.invalidate()
            avPlayer?.pause()
            pushEvent(eventName: Constants.FLUTTER_RADIO_PAUSED)
        }

        return PlayerStatus.PAUSE
    }

    func stop() -> PlayerStatus {
        print("invoking stop method on service")
        if (isPlaying()) {
            pushEvent(eventName: Constants.FLUTTER_RADIO_STOPPED)
            avPlayer = nil
            avPlayerItem = nil
            commandCenter = nil
        }

        return PlayerStatus.STOPPED
    }

    func isPlaying() -> Bool {
        let status = (avPlayer?.rate != 0 && avPlayer?.error == nil) ? true : false
        print("isPlaying status: \(status)")
        return status
    }

    func setVolume(volume: NSNumber) -> Void {
        let formattedVolume = volume.floatValue;
        print("Setting volume to: \(formattedVolume)")
        avPlayer?.volume = formattedVolume
    }

    func setUrl(streamURL: String, playWhenReady: String) -> Void {
            streamLink = streamURL
            let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
            metadataOutput.setDelegate(self, queue: DispatchQueue.main)
            let streamURLInstance = URL(string: streamURL)
            avPlayerItem = AVPlayerItem(url: streamURLInstance!)
            avPlayerItem?.add(metadataOutput)
            avPlayer?.replaceCurrentItem(with: avPlayerItem)

            if playWhenReady == "true" {
                self.playWhenReady = true
                play()
            } else {
                self.playWhenReady = false
                pause()
            }
    }

    @objc func timerAction() {
       pause()
    }

    private func pushEvent(typeEvent : String = "status", eventName: String) {
        print("Pushing event: \(eventName)")
        NotificationCenter.default.post(name: Notifications.playbackNotification, object: nil, userInfo: [typeEvent: eventName])
    }

    private func initRemoteTransportControl(appName: String, subTitle: String) {

        do {
            commandCenter = MPRemoteCommandCenter.shared()

            // build now playing

            var image: MPMediaItemArtwork = MPMediaItemArtwork(image: UIImage(named:"radio_notification_image")!)
            if streamLink != "http://almalakradio.out.airtime.pro:8000/almalakradio_a?_ga=2.259920074.1336436179.1510295339-974603170.1506885966" {
                image = MPMediaItemArtwork(image: UIImage(named:"live_notification_image")!)
            }
            var nowPlayingInfo: [String : Any] = [MPMediaItemPropertyArtist: "" , MPMediaItemPropertyTitle: "Almalak radio",
            MPMediaItemPropertyArtwork: image
            ]
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

            // basic command center options
            commandCenter?.togglePlayPauseCommand.isEnabled = true
            commandCenter?.playCommand.isEnabled = true
            commandCenter?.pauseCommand.isEnabled = true
            commandCenter?.nextTrackCommand.isEnabled = false
            commandCenter?.previousTrackCommand.isEnabled = false
            commandCenter?.changePlaybackRateCommand.isEnabled = false
            commandCenter?.skipForwardCommand.isEnabled = false
            commandCenter?.skipBackwardCommand.isEnabled = false
            commandCenter?.ratingCommand.isEnabled = false
            commandCenter?.likeCommand.isEnabled = false
            commandCenter?.dislikeCommand.isEnabled = false
            commandCenter?.bookmarkCommand.isEnabled = false
            commandCenter?.changeRepeatModeCommand.isEnabled = false
            commandCenter?.changeShuffleModeCommand.isEnabled = false

            // only available in iOS 9
            if #available(iOS 9.0, *) {
                commandCenter?.enableLanguageOptionCommand.isEnabled = false
                commandCenter?.disableLanguageOptionCommand.isEnabled = false
            }

            // control center play button callback
            commandCenter?.playCommand.addTarget { (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus in
                print("command center play command...")
                _ = self.play()
                return .success
            }

            // control center pause button callback
            commandCenter?.pauseCommand.addTarget { (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus in
                print("command center pause command...")
                _ = self.pause()
                return .success
            }

            // control center stop button callback
            commandCenter?.stopCommand.addTarget { (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus in
                print("command center stop command...")
                _ = self.stop()
                return .success
            }

            // create audio session for background playback and control center callbacks.
            let audioSession = AVAudioSession.sharedInstance()

            if #available(iOS 10.0, *) {
                try audioSession.setCategory(.playback, mode: .default, options: .defaultToSpeaker)
                try audioSession.overrideOutputAudioPort(.speaker)
                try audioSession.setActive(true)
            }

            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Something went wrong ! \(error)")
        }
    }

    private func initPlayerObservers() {
        print("Initializing player observers...")
        // Add observer for AVPlayer.Status and AVPlayerItem.currentItem
        self.avPlayer?.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.new, .initial], context: nil)
        self.avPlayer?.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.status), options:[.new, .initial], context: nil)
        self.avPlayer?.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.isPlaybackBufferEmpty), options:[.new, .initial], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {

        if object is AVPlayer {
            switch keyPath {

            case #keyPath(AVPlayer.currentItem.isPlaybackBufferEmpty):
                let _: Bool
                if let newStatusNumber = change?[NSKeyValueChangeKey.newKey] as? Bool {
                    if newStatusNumber {
                        print("Observer: Stalling...")
                        pushEvent(eventName: Constants.FLUTTER_RADIO_LOADING)
                    }
                }

            case #keyPath(AVPlayer.currentItem.status):
                let newStatus: AVPlayerItem.Status
                if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                    newStatus = AVPlayerItem.Status(rawValue: newStatusAsNumber.intValue)!
                } else {
                    newStatus = .unknown
                }

                if newStatus == .readyToPlay {
                    print("Observer: Ready to play...")
                    pushEvent(eventName: isPlaying()
                                ? Constants.FLUTTER_RADIO_PLAYING
                                : Constants.FLUTTER_RADIO_PAUSED)
                    if !isPlaying() && self.playWhenReady {
                        play()
                    }
                }

                if newStatus == .failed {
                    print("Observer: Failed...")
                    pushEvent(eventName: Constants.FLUTTER_RADIO_ERROR)
                }
            case #keyPath(AVPlayer.status):
                print()
            case .none:
                print("none...")
            case .some(_):
                print("some...")
            default:
                if keyPath != nil {
                    print("Observer: unhandled change for keyPath " + keyPath!)
                }
            }
        }
    }

}