//
//  RTPStats.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 03/06/21.
//

import Foundation
import MachO
import UIKit

struct rtp_stats_config {
    static var localFractionLoss: Double = 0.0
    static var remoteFractionLoss: Double = 0.0
    static var localPacketsLost: Int = 0
    static var localPacketsSent: Int = 0
    static var remotePacketsLost: Int = 0
    static var remotePacketsReceived: Int = 0
    static var prePacketsReceived: Int = 0
    static var prePacketsSent: Int = 0
    static var preRemotePacketsLoss: Int = 0
    static var preLocalPacketsLoss: Int = 0
}

var rttArray: [Any]?
var mosArray: [Any]?
var jitterLocalArray: [Any]?
var jitterRemoteArray: [Any]?
var packetLossLocalArray: [Any]?
var packetLossRemoteArray: [Any]?
var audioLevelLocalArray: [Any]?
var audioLevelRemoteArray: [Any]?

var mediaStorage: [String : Any]?
var mediaWarning: [String : Any]?

let codecName: String? = nil

protocol RTPStatsDelegate {
    func emitMediaMetrics(_ group: String, _ level: String, _ type: String, _ value: Double, _ active: Bool, _ desc: String, _ stream: String)
}

class RtpStats: NSObject {

    var delegate:RTPStatsDelegate?

    override init() {
        mediaStorage = [String : Any]()
        mediaStorage?["rtt"] = [AnyHashable]()
        mediaStorage?["mos"] = [AnyHashable]()
        mediaStorage?["jitterLocalMeasures"] = [AnyHashable]()
        mediaStorage?["jitterRemoteMeasures"] = [AnyHashable]()
        mediaStorage?["packetLossLocalMeasures"] = [AnyHashable]()
        mediaStorage?["packetLossRemoteMeasures"] = [AnyHashable]()
        mediaStorage?["audioLevelLocalMeasures"] = [AnyHashable]()
        mediaStorage?["audioLevelRemoteMeasures"] = [AnyHashable]()

        mediaWarning = [String : Any]()
        mediaWarning?["rtt"] = NSNumber(value: false)
        mediaWarning?["mos"] = NSNumber(value: false)
        mediaWarning?["jitterLocalMeasures"] = NSNumber(value: false)
        mediaWarning?["jitterRemoteMeasures"] = NSNumber(value: false)

        mediaWarning?["packetLossLocalMeasures"] = NSNumber(value: false)
        mediaWarning?["rtpacketLossRemoteMeasurest"] = NSNumber(value: false)
        mediaWarning?["audioLevelLocalMeasures"] = NSNumber(value: false)
        mediaWarning?["audioLevelRemoteMeasures"] = NSNumber(value: false)
        mediaWarning?["microphoneAccess"] = NSNumber(value: false)

        LogManager.shared.log("init RTPStats class", level: .alert)
    }

    deinit {
        LogManager.shared.log("deinit RTPStats class", level: .alert)
    }

    private func getDarwinVersion() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return String(bytes: Data(bytes: &systemInfo.release, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? "NA"
    }

    private func getCFNetworkVersion() -> String {
        if let bundle = Bundle(identifier: "com.apple.CFNetwork")?.infoDictionary?["CFBundleShortVersionString"] {
            return "CFNetwork/\(bundle)"
        }
        return "NA"
    }

    private func getDeviceVersion() -> String {
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        return "\(systemName)/\(systemVersion)"
    }

    private func getDeviceName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return String(bytes: Data(bytes: &systemInfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? "NA"
    }

    private func getAppName() -> String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        return "\(appName ?? "")"
    }

    private func getAppVersion() -> String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "\(appVersion ?? "")"
    }

    private func getArchitecture() -> String {
        let info = NXGetLocalArchInfo()
        guard let cpu = info?.pointee.description else { return "NA" }
        let typeOfCpu = String(utf8String: cpu)
        return typeOfCpu ?? "NA"
    }

    private func getUAString() -> String {
        return "\(getAppName())/\(getAppVersion()) \(getDeviceName()) \(getDeviceVersion()) \(getCFNetworkVersion()) \(getDarwinVersion()) \(getArchitecture())"
    }

    //TODO:Check below method logic
    private func getMOS(_ stream_stat :[String : Any], _ statsType: String?) -> Double {
        //    Calculate R
        var jitter:Double = 0.0, fractionLoss:Double = 0.0, R:Double = 0.0, MOS:Double = 0.0;
        var RValue = 0.0

        if (statsType == "local") {
            if let localrtp = stream_stat["remote-inbound-rtp"] as? [String:Any]{
                jitter = (localrtp["jitter"] as? Double ?? 0)
            }

            fractionLoss = rtp_stats_config.localFractionLoss;
        } else {
            if let remotertp = stream_stat["remote-rtp"] as? [String:Any]{
                jitter = (remotertp["jitter"] as? Double ?? 0)
            }

            fractionLoss = rtp_stats_config.remoteFractionLoss;
        }

        if let localCodec = stream_stat["codec"] as? String, localCodec == "opus"{
            RValue = 95.0
        }else{
            RValue = 93.2
        }

        var effectiveLatency:Double = 0.0

        if let localrtp = stream_stat["remote-inbound-rtp"] as? [String:Any]{
            effectiveLatency = Double((localrtp["roundTripTime"] as? Double ?? 0.0) / 2000.0) + (jitter * 2) + 10
        }

        if(effectiveLatency < 160){
            R = RValue - (effectiveLatency/40);
        }else{
            R = RValue - (effectiveLatency - 120)/10;
        }
        R = R - (fractionLoss * 2.5);
        if (R <= 0) {
            MOS = 1;
        } else if (R > 100) {
            MOS = 4.5;
        } else {
            MOS = 1 + 0.035 * R + 7.10/1000000 * R * (R - 60) * (100 - R);
        }
        return MOS
    }

    private func processMetrics(_ type: String, _ val: Double, _ msg: String, _ desc: String, _ stream: String) {
        var metricArr = [Any]()
        if let metricObj:[Any] = mediaStorage?[type] as? [String], metricObj.count == 2 {
            metricArr = metricObj
            metricArr.append(val)
            let totMetricObj = filterMetricObj(&metricArr, type) as NSArray
            if totMetricObj.count >= 2 {
                mediaWarning?[type] = NSNumber(value: true)
                let avg = totMetricObj.value(forKeyPath: "@avg.doubleValue")
                LogManager.shared.log("Getting \(msg ): \(totMetricObj.componentsJoined(by: ","))", level: .debug)
                delegate?.emitMediaMetrics("network", "warning", msg, avg as? Double ?? 0.0, true, desc, stream)
            } else {
                if ((mediaWarning?[type]) != nil) {
                    mediaWarning?[type] = NSNumber(value: false)
                    delegate?.emitMediaMetrics("network", "warning", msg, 0, false, desc, stream)
                }
            }
        } else {
            metricArr.append(NSNumber(value: val))
        }
        if metricArr.count == 3 {
            if let subRange = Range(NSRange(location: 0, length: 1)) { metricArr.removeSubrange(subRange) }
        }
    }

    private func filterMetricObj(_ metricObj: inout [Any], _ type: String?) -> [Any] {
        var totMetricObj: [Any] = []
        for obj in metricObj {
            if type == "rtt" {
                if (obj as? NSNumber)?.doubleValue ?? 0.0 > 400 {
                    totMetricObj.append(obj)
                }
            } else if type == "mos" {
                if (obj as? NSNumber)?.doubleValue ?? 0.0 < 3.5 {
                    totMetricObj.append(obj)
                }
            } else if (type == "jitterLocalMeasures") || (type == "jitterRemoteMeasures") {
                if (obj as? NSNumber)?.doubleValue ?? 0.0 > 30 {
                    totMetricObj.append(obj)
                }
            } else if (type == "packetLossLocalMeasures") || (type == "packetLossRemoteMeasures") {
                if ((codecName?.hasPrefix("PCMU")) != nil) {
                    if (obj as? NSNumber)?.doubleValue ?? 0.0 >= 0.02 {
                        totMetricObj.append(obj)
                    }
                } else {
                    if (obj as? NSNumber)?.doubleValue ?? 0.0 >= 0.10 {
                        totMetricObj.append(obj)
                    }
                }
            }
        }
        return totMetricObj
    }

    private func processAudioLevel(_ type: String, _ val: Double, _ msg: String, _ desc: String, _ stream: String) {
        var metricArr = [Any]()
        if let metricObj:[Any] = mediaStorage?[type] as? [String], metricObj.count == 2 {
            metricArr = metricObj
            metricArr.append(val)
            var identicalCollector: [AnyHashable : Any] = [:]
            var audioVol: Double = 0.0
            for obj in metricObj {
                if identicalCollector[NSNumber(value: (obj as? NSNumber)?.doubleValue ?? 0.0)] != nil {
                    identicalCollector[NSNumber(value: (obj as? NSNumber)?.doubleValue ?? 0.0)] = NSNumber(
                        value: Int32((identicalCollector[NSNumber(value: (obj as? NSNumber)?.doubleValue ?? 0.0)] as? NSNumber)?.intValue ?? 0 + 1))
                } else {
                    identicalCollector[NSNumber(value: (obj as? NSNumber)?.doubleValue ?? 0.0)] = NSNumber(value: 1)
                }
                if (identicalCollector[NSNumber(value: (obj as? NSNumber)?.doubleValue ?? 0.0)] as? NSNumber)?.intValue ?? 0 >= 2 {
                    audioVol = (obj as? NSNumber)?.doubleValue ?? 0.0
                }
            }
            if audioVol == -100 {
                mediaWarning?[type] = NSNumber(value: true)
//                LogManager.shared.log( "Audio mute detected for \(type): \(metricArr.componentsJoined(by: ","))", level: .debug)
                delegate?.emitMediaMetrics("network", "warning", msg, audioVol, true, desc, stream)
            } else {
                if ((mediaWarning?[type]) != nil) {
                    mediaWarning?[type] = NSNumber(value: false)
                    delegate?.emitMediaMetrics("network", "warning", msg, 0, false, desc, stream)
                }
            }
        } else {
            metricArr.append(NSNumber(value: val))
        }
        if metricArr.count == 3 {
            if let subRange = Range(NSRange(location: 0, length: 1)) { metricArr.removeSubrange(subRange) }
        }
    }

    private func checkMicrophoneAccess(_ type: String, _ bytes: Int, _ audioLevel: Double, _ msg: String) {
        if bytes == 0 && audioLevel == -100 {
            mediaWarning?[type] = NSNumber(value: true)
            delegate?.emitMediaMetrics("network", "warning", msg, 0, true, "Access to microphone not given", "None")
        } else {
            if ((mediaWarning?[type]) != nil) {
                mediaWarning?[type] = NSNumber(value: false)
                delegate?.emitMediaMetrics("network", "warning", msg, 0, false, "Access to microphone given", "None")
            }
        }
    }

    private func getAudioLevel(_ audioLevelAmplitude: Double) -> Double {
        var audioLevelDecibles: Double = -100.0
        if audioLevelAmplitude != 0.0 {
            audioLevelDecibles = 20 * log10(audioLevelAmplitude / 255.0)
        }
        if audioLevelDecibles.isNaN{
            return 0.0
        }else{
            return Double(String(format: "%.03f", audioLevelDecibles)) ?? 0.0
        }
    }

    private func calculateFractionLoss(stream_stat :[String : Any]) {

        if let remoteinbound = stream_stat["remote-inbound-rtp"] as? [String:Any]{
            rtp_stats_config.localPacketsSent =  (remoteinbound["packetsSent"] as? Int ?? 0) - rtp_stats_config.prePacketsSent
        }

        if let localrtp = stream_stat["local-rtp"] as? [String:Any]{
            rtp_stats_config.localPacketsLost = (localrtp["packetsLost"] as? Int ?? 0) - rtp_stats_config.preLocalPacketsLoss
            rtp_stats_config.localFractionLoss = (rtp_stats_config.localPacketsLost == 0 && rtp_stats_config.localPacketsSent == 0) ? 0.0 : (rtp_stats_config.localPacketsSent == 0) ? 1.0 : Double(rtp_stats_config.localPacketsLost / rtp_stats_config.localPacketsSent)
        }

        if let report = stream_stat["remote-rtp"] as? [String:Any], let received = report["packetsReceived"] as? Int, let lost = report["packetsLost"] as? Int{
            rtp_stats_config.remotePacketsLost = lost - rtp_stats_config.preRemotePacketsLoss;
            rtp_stats_config.remotePacketsReceived = received - rtp_stats_config.prePacketsReceived+rtp_stats_config.remotePacketsLost;
            rtp_stats_config.remoteFractionLoss = (rtp_stats_config.remotePacketsLost == 0 && rtp_stats_config.remotePacketsReceived == 0 ) ? 0.0 : (rtp_stats_config.remotePacketsReceived == 0) ? 1.0 : Double(rtp_stats_config.remotePacketsLost / rtp_stats_config.remotePacketsReceived)
        }

        basePackets(stream_stat: stream_stat);
    }

    private func basePackets(stream_stat :[String : Any]) {
        if let report = stream_stat["remote-rtp"] as? [String:Any], let received = report["packetsReceived"] as? Int, let lost = report["packetsLost"] as? Int{
            rtp_stats_config.prePacketsReceived = received
            rtp_stats_config.preRemotePacketsLoss = lost
        }

        if let localrtp = stream_stat["local-rtp"] as? [String:Any]{
            rtp_stats_config.prePacketsSent = (localrtp["packetsSent"] as? Int ?? 0)
            rtp_stats_config.preLocalPacketsLoss = (localrtp["packetsLost"] as? Int ?? 0)
        }
    }

    func getInitialStats(isCallAnswered: Bool) -> [String : Any] {
        if isCallAnswered {
            rtp_stats_config.preLocalPacketsLoss = 0
            rtp_stats_config.prePacketsSent = 0
            rtp_stats_config.preRemotePacketsLoss = 0
            rtp_stats_config.prePacketsReceived = 0
        }
        var dict: [String : Any] = [:]
        let sdkVersion = Constant.PLIVO_ENDPOINT_VER.components(separatedBy: ".")
        let appVersionString = getAppVersion()
        let appVersion = appVersionString.components(separatedBy: ".")

        let sdkInfo = [
            "userAgent": getUAString(),
            "sdkVersionMajor": sdkVersion[0],
            "sdkVersionMinor": sdkVersion[1],
            "sdkVersionPatch": sdkVersion[2],
            "clientName": getAppName(),
            "deviceOs": UIDevice.current.systemName,
            "devicePlatform": getArchitecture(),
            "domain": Environment.sipDomain,
            "sdkName": Constant.SDK_NAME,
            "source": Constant.STATS_SOURCE,
            "version": Constant.STATS_VERSION,
            "timeStamp": Utils.getCurrentTimeInMilliSeconds()
        ] as [String : Any]

        for (k, v) in sdkInfo { dict[k] = v }

        if appVersion.count == 3 {
            dict["clientVersionMajor"] = appVersion[0]
            dict["clientVersionMinor"] = appVersion[1]
            dict["clientVersionPatch"] = appVersion[2]
        } else {
            dict["clientVersionMajor"] = NSNull()
            dict["clientVersionMinor"] = NSNull()
            dict["clientVersionPatch"] = NSNull()
        }

        return dict
    }

    func getLocalStats(_ streamStats: [String : Any]) -> [String : Any] {

        calculateFractionLoss(stream_stat: streamStats)

        var MOSLocal: Double = 0.0
        var MOSRemote: Double = 0.0
        var MOS: Double = 0.0

        MOSLocal = getMOS(streamStats, "local")
        MOSRemote = getMOS(streamStats, "remote")
        MOS = Double(min(MOSLocal, MOSRemote))

        var rtt:Double = 0.0
        var bytesSent = 0
        var audioLevel:Double = 0.0
        var jitter:Double = 0.0
        var src = 0
        var packetsLost = 0
        var packetsSent = 0

        if let remoteinbound = streamStats["remote-inbound-rtp"] as? [String:Any]{
            rtt = (remoteinbound["roundTripTime"] as? Double ?? 0.0) * 1000
            packetsLost = remoteinbound["packetsLost"] as? Int ?? 0
            jitter = (remoteinbound["jitter"] as? Double ?? 0.0)
        }

        if let mediasource = streamStats["media-source"] as? [String:Any]{
            audioLevel = getAudioLevel(mediasource["audioLevel"] as? Double ?? 0.0)
        }

        if let localrtp = streamStats["local-rtp"] as? [String:Any]{
            bytesSent = localrtp["bytesSent"] as? Int ?? 0
            src = localrtp["ssrc"] as? Int ?? 0
            packetsSent = localrtp["packetsSent"] as? Int ?? 0
        }


        let localStatsDict = [
            "audioLevel": String(format: "%.02f",audioLevel),
            "bytesSent": NSNumber(value: bytesSent),
            "fractionLoss": NSNumber(value: Double(String(format: "%.02f", rtp_stats_config.localFractionLoss)) ?? 0.0),
            "rtt": String(format: "%.02f", rtt),
            "mos": String(format: "%.02f", MOS),
            "jitter": String(format: "%.02f", jitter),
            "packetsLost": packetsLost,
            "packetsSent": packetsSent,
            "ssrc": src
        ] as [String : Any]

        processMetrics("rtt", rtt, "high_rtt", "high latency detected, can result delay in audio", "None")
        processMetrics("mos", MOS, "low_mos", "low Mean Opinion Score (MOS)", "None")
        processMetrics("jitterLocalMeasures", jitter, "high_jitter", "high jitter detected due to network congestion, can result in audio quality problems", "local")
        processMetrics("packetLossLocalMeasures", rtp_stats_config.localFractionLoss, "high_packetloss", "high packet loss is detected on media stream, can result in choppy audio or dropped call", "local")
        processAudioLevel("audioLevelLocalMeasures", audioLevel, "no_audio_received", "no audio packets received", "local")
        checkMicrophoneAccess("microphoneAccess", bytesSent, audioLevel, "no_microphone_access")

        return localStatsDict
    }

    func getRemoteStats(_ streamStats: [String : Any]) -> [String : Any] {

        calculateFractionLoss(stream_stat: streamStats)

        var audioLevel:Double = 0.0
        var bytesReceived = 0
        var jitter:Double = 0.0
        var src = 0
        var packetsLost = 0
        var packetsReceived = 0

        if let remotertp = streamStats["remote-rtp"] as? [String:Any]{
            jitter = remotertp["jitter"] as? Double ?? 0.0
            src = remotertp["ssrc"] as? Int ?? 0
            audioLevel = getAudioLevel(remotertp["audioLevel"] as? Double ?? 0.0)
            packetsLost = remotertp["packetsLost"] as? Int ?? 0
            packetsReceived = remotertp["packetsReceived"] as? Int ?? 0
            bytesReceived = remotertp["bytesReceived"] as? Int ?? 0
        }

        let remoteStatsDict = [
            "audioLevel": String(format: "%.02f",audioLevel),
            "bytesReceived": bytesReceived,
            "fractionLoss": NSNumber(value: Double(String(format: "%.02f", rtp_stats_config.remoteFractionLoss)) ?? 0.0),
            "jitter": String(format: "%.02f", jitter),
            "packetsLost": packetsLost,
            "packetsReceived": packetsReceived,
            "ssrc": src
        ] as [String : Any]

        processMetrics("jitterRemoteMeasures", jitter, "high_jitter", "high jitter detected due to network congestion, can result in audio quality problems", "remote")

        processMetrics("packetLossRemoteMeasures", rtp_stats_config.remoteFractionLoss, "high_packetloss", "high packet loss is detected on media stream, can result in choppy audio or dropped call", "remote")
        processAudioLevel("audioLevelRemoteMeasures", audioLevel, "no_audio_received", "no audio packets received", "remote")

        return remoteStatsDict
    }

    func getCallStatsKey() {
        LogManager.shared.log(" getCallStatsKey() | Getting call stats key", level: .debug)

        let userDictionary = [
            "username" : StatsConfig.username ?? "NA",
            "password" : StatsConfig.password ?? "NA",
            "domain" : Environment.sipDomain
        ]

        if JSONSerialization.isValidJSONObject(userDictionary) {
            HTTPClient.shared.postRequest(url: Constant.STATS_API_URL, params: userDictionary) { (response) in
                switch response{
                case let .success(value):
                    if let json = value as? [String: Any]{
                        StatsConfig.stats_key = json["data"] as? String ?? ""
                        StatsConfig.rtp_enabled = json["is_rtp_enabled"] as? Bool ?? false
                    }else{
                        LogManager.shared.log("Call stats is disabled. Not sending stats", level: .error)
                        LogManager.shared.log("Response from validate API is null", level: .error)
                        StatsConfig.stats_key = nil
                        StatsConfig.rtp_enabled = false
                    }
                    break
                case let .failure(error):
                    LogManager.shared.log("Call stats is disabled. Not sending stats", level: .error)
                    LogManager.shared.log("error is calling validate API \(error)", level: .error)
                    StatsConfig.stats_key = nil
                    StatsConfig.rtp_enabled = false
                    break
                }
            }
        }else{
            LogManager.shared.log("Error while getCallStatsKey() userDictionary is not valid", level: .error)
        }
    }

    func getSignallingStats()->[AnyHashable : Any]{
        var signalDict = [AnyHashable : Any]()
        signalDict["answer_time"] = StatsConfig.answer_time
        signalDict["call_confirmed_time"] = StatsConfig.call_confirmed_time
        signalDict["call_initiation_time"] = StatsConfig.call_initiation_time
        signalDict["hangup_party"] = StatsConfig.hangup_party
        signalDict["hangup_reason"] = StatsConfig.hangup_reason
        signalDict["hangup_time"] = StatsConfig.hangup_time
        if StatsConfig.postDialDelayEndTime != nil && StatsConfig.call_initiation_time != nil{
            signalDict["post_dial_delay"] = "\(StatsConfig.postDialDelayEndTime!.floatValue - StatsConfig.call_initiation_time!.floatValue)"
        }else{
            signalDict["post_dial_delay"] = "0"
        }
        if(StatsConfig.ring_start_time != nil) {
            signalDict["ring_start_time"] = StatsConfig.ring_start_time;
        } else if(StatsConfig.call_progress_time != nil) {
            signalDict["call_progress_time"] = StatsConfig.call_progress_time;
        }
        return signalDict
    }

}

