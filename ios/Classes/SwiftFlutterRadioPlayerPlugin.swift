import Flutter
import UIKit

var streamLink: String = ""
var previousStatus: String = ""

public class SwiftFlutterRadioPlayerPlugin: NSObject, FlutterPlugin {

    private var streamingCore: StreamingCore = StreamingCore()

    public static var mEventSink: FlutterEventSink?
    public static var eventSinkMetadata: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_radio_player", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterRadioPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // register the event channel
        let eventChannel = FlutterEventChannel(name: "flutter_radio_player_stream", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(StatusStreamHandler())

        let eventChannelMetadata = FlutterEventChannel(name: "flutter_radio_player_meta_stream", binaryMessenger: registrar.messenger())
        eventChannelMetadata.setStreamHandler(MetaDataStreamHandler())
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if(call.method.contains("play ")) {
            let start = call.method.index(call.method.startIndex, offsetBy: 5)
            let range = start..<call.method.endIndex
            let durationString = call.method[range]
            let duration = Double(durationString)
            if(duration == -1){
                timer.invalidate()
            } else {
                timer = Timer()
                timer = Timer.scheduledTimer(timeInterval: duration! * 60, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
            }
            let status = streamingCore.play(duration: duration!)
            if (status == PlayerStatus.PLAYING) {
                result(true)
            }
            result(false)
        }
        switch (call.method) {
        case "initService":
            print("method called to start the radio service")
            if let args = call.arguments as? Dictionary<String, Any>,
                let streamURL = args["streamURL"] as? String,
                let appName = args["appName"] as? String,
                let subTitle = args["subTitle"] as? String,
                let playWhenReady = args["playWhenReady"] as? String
            {
                streamLink = streamURL

                streamingCore.initService(streamURL: streamURL, serviceName: appName, secondTitle: subTitle, playWhenReady: playWhenReady)

                NotificationCenter.default.addObserver(self, selector: #selector(onRecieve(_:)), name: Notifications.playbackNotification, object: nil)
                result(nil)
            }
            break
        case "playOrPause":
            print("method called to playOrPause from service")
            if (streamingCore.isPlaying()) {
                _ = streamingCore.pause()
            } else {
                _ = streamingCore.play()
            }
        case "play":
            print("method called to play from service")
            timer.invalidate()
            let status = streamingCore.play()
            if (status == PlayerStatus.PLAYING) {
                result(true)
            }
            result(false)
            break
        case "pause":
            print("method called to play from service")
            timer.invalidate()
            let status = streamingCore.pause()
            if (status == PlayerStatus.IDLE) {
                result(true)
            }
            result(false)
            break
        case "stop":
            print("method called to stopped from service")
            timer.invalidate()
            let status = streamingCore.stop()
            if (status == PlayerStatus.STOPPED) {
                result(true)
            }
            result(false)
            break
        case "isPlaying":
            print("method called to is_playing from service")
            result(streamingCore.isPlaying())
            break
        case "setVolume":
            print("method called to setVolume from service")
            if let args = call.arguments as? Dictionary<String, Any>,
                let volume = args["volume"] as? NSNumber {
                print("Received set to volume: \(volume)")
                streamingCore.setVolume(volume: volume)
            }
            result(nil)
        case "setUrl":
            if let args = call.arguments as? Dictionary<String, Any>,
                let streamURL = args["streamUrl"] as? String,
                let playWhenReady = args["playWhenReady"] as? String
            {
                streamLink = streamURL
                print("method called to setUrl")
                streamingCore.setUrl(streamURL: streamURL, playWhenReady: playWhenReady)
            }
            result(nil)
        default:
            result(nil)
        }
    }

    @objc func timerAction() {
       streamingCore.pause()
    }

    @objc private func onRecieve(_ notification: Notification) {
        // unwrapping optional
        if let playerEvent = notification.userInfo!["status"] {
            print("Notification received with event name: \(playerEvent)")
            if(previousStatus == "") {
                previousStatus = "\(playerEvent)"
            }
            if("\(playerEvent)" == "flutter_radio_playing" && previousStatus == "flutter_radio_paused") {
                streamingCore.setUrl(streamURL: streamLink, playWhenReady: "true")
            } else {
                SwiftFlutterRadioPlayerPlugin.mEventSink?(playerEvent)
            }
            previousStatus = "\(playerEvent)"
        }

        if let metaDataEvent = notification.userInfo!["meta_data"] {
            print("Notification received with metada: \(metaDataEvent)")
            SwiftFlutterRadioPlayerPlugin.eventSinkMetadata?(metaDataEvent as! String)
        }

    }
}



class StatusStreamHandler: NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        SwiftFlutterRadioPlayerPlugin.mEventSink = events
        return nil;
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        SwiftFlutterRadioPlayerPlugin.mEventSink = nil
        return nil;
    }
}

class MetaDataStreamHandler: NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        SwiftFlutterRadioPlayerPlugin.eventSinkMetadata = events
        return nil;
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        SwiftFlutterRadioPlayerPlugin.eventSinkMetadata = nil
        return nil;
    }
}
