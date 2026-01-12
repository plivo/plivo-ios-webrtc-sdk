//
//  PlivoOutgoing.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 02/02/21.
//

import Foundation

@objc public class PlivoOutgoing: NSObject {
    
    /// The accId of the registered Endpoint
    public var accId:PlivoAccId?
    
    /// The callId of the call
    @objc public var callId:String?
    
    /// State of the call
    public internal(set) var state:PlivoCallState?
    private var sipAdapter:SipAdapter?
    var webrtcAdapter: WebrtcAdapter?
    private var feedbackManager: FeedbackManager?
    private var callUri:String?
    var headers:[AnyHashable:Any]?
    private var jwtToken: String = ""
    var isHold = false;
    var isMute = false;
    private var rtpStats: RtpStats?
    var speechTimer: Timer?
    
    public override init() {
        super.init()
        self.callId = ""
    }
    
    convenience init(sipAdapter:SipAdapter, webrtcAdapter:WebrtcAdapter, feedbackManager: FeedbackManager, rtpStats: RtpStats) {
        self.init()
        LogManager.shared.log("init PlivoOutgoing", level: .debug)
        self.sipAdapter = sipAdapter
        self.webrtcAdapter = webrtcAdapter
        self.webrtcAdapter?.outgoingDelegate = self
        self.jwtToken = StatsConfig.access_token ?? ""
        self.feedbackManager = feedbackManager
        self.rtpStats = rtpStats
    }
        
    func stopSpeechRecognition(){
        if let rtpStats = self.rtpStats {
            rtpStats.stopSpeechRecognition()
        } else {
            LogManager.shared.log("rtpstats instance is nil", level: .error)
        }
    }
    
    func startSpeechRecognition(){
        if let rtpStats = self.rtpStats,
           let webrtcAdapter = self.webrtcAdapter {
            rtpStats.startSpeechRecognition(webrtcAdapter: webrtcAdapter)
        } else {
            LogManager.shared.log("instances are nil", level: .error)
        }
    }
    
    deinit {
        LogManager.shared.log("deinit PlivoOutgoing", level: .debug)
    }
    
    /// Calling this method on the PlivoOutgoing object with the SIP URI would initiate an outbound call.
    /// - Parameter sipURI: sipURI
    @objc public func call(_ sipURI: String) -> Bool{
        LogManager.shared.infoLogs(log: "Outgoing | call initiated")
        if !self.jwtToken.isEmpty {
            self.call(sipURI, headers: [:])
            return false
        }
        
        if Utils.IS_CALL_RUNNING{
            LogManager.shared.log("\(Constant.ALREADY_ONE_ACTIVE_CALL) \(sipURI)", level: .error)
            LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.ALREADY_ONE_ACTIVE_CALL)")
            return false
        }
        
        callUri = sipURI.fixedSipUri
        
        if (callUri?.count ?? 0) < 0{
            LogManager.shared.log("\(Constant.INVALID_SIP_URI) \(sipURI)", level: .error)
            LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.INVALID_SIP_URI)")
            return  false
        }
        
        if callUri!.isAlphanumeric == true || (callUri!.hasPrefix("+") && callUri!.removingPrefix("+").isNumeric) || callUri!.contains("_"){
            self.state = .Dialing
            self.initiateWebrtcCall(isIceRestartRequired: false, headers: nil)
            return true
        }else{
            LogManager.shared.log("\(Constant.INVALID_SIP_URI) \(sipURI)", level: .error)
            LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.INVALID_SIP_URI)")
            return false
        }
    }
    
    /// Calling this method on the PlivoOutgoing object with the SIP URI would initiate an outbound call.
    /// - Parameters:
    ///   - sipURI: sipURI
    ///   - error: error
    @objc public func call(_ sipURI: String, error: UnsafeMutablePointer<NSError?>) -> Bool{
        LogManager.shared.infoLogs(log: "Outgoing | call initiated")
        if !self.jwtToken.isEmpty {
            self.call(sipURI, headers: [:], error: error)
            return false
        }
        
        if Utils.IS_CALL_RUNNING{
            LogManager.shared.log("\(Constant.ALREADY_ONE_ACTIVE_CALL) \(sipURI)", level: .error)
            LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.ALREADY_ONE_ACTIVE_CALL)")
            return false
        }
        
        callUri = sipURI.fixedSipUri
        
        if (callUri?.count ?? 0) < 0{
            LogManager.shared.log("\((Constant.INVALID_SIP_URI)) \(sipURI)", level: .error)
            LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.INVALID_SIP_URI)")
            if error != nil {
                let domain = Environment.bundleId
                let desc = Constant.EMPTY_URI
                let userInfo = [
                    NSLocalizedDescriptionKey: desc
                ]
                
                error.pointee = NSError(domain: domain, code: 298, userInfo: userInfo)
            }
            return false
        }
        
        if callUri!.isAlphanumeric == true || (callUri!.hasPrefix("+") && callUri!.removingPrefix("+").isNumeric) || callUri!.contains("_") {
            self.state = .Dialing
            self.initiateWebrtcCall(isIceRestartRequired: false, headers: nil)
            return true
        }else{
            LogManager.shared.log("\((Constant.INVALID_SIP_URI)) \(sipURI)", level: .error)
            LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.INVALID_SIP_URI)")
            if error != nil {
                let domain = Environment.bundleId
                let desc = Constant.EMPTY_URI
                let userInfo = [
                    NSLocalizedDescriptionKey: desc
                ]
                
                error.pointee = NSError(domain: domain, code: 298, userInfo: userInfo)
            }
            return false
        }
    }
    
    /// Calling this method on the PlivoOutgoing object with the SIP URI would initiate an outbound call with custom SIP headers.
    /// - Parameters:
    ///   - sipURI: sipURI
    ///   - headers: headers
    @objc public func call(_ sipURI: String, headers: [AnyHashable : Any]) -> Bool {
        var extraHeaders = headers
        LogManager.shared.infoLogs(log: "Outgoing | call initiated with header: \(headers) and destination: \(sipURI)")
        if !self.jwtToken.isEmpty {
            extraHeaders["X-Plivo-Jwt"] = self.jwtToken
        }
        
        if Utils.IS_CALL_RUNNING{
            LogManager.shared.log("\(Constant.ALREADY_ONE_ACTIVE_CALL) \(sipURI)", level: .error)
            LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.ALREADY_ONE_ACTIVE_CALL)")
            return false
        }
        
        var header_length = 0
        // Custom Headers
        let keys = extraHeaders.keys
        header_length = Int(keys.count )
        
        if header_length == 0 {
            LogManager.shared.log(Constant.ERROR_IN_CALL_WITH_HEADERS_NO_HEADER, level :.error)
            LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.ERROR_IN_CALL_WITH_HEADERS_NO_HEADER)")
            return self.call(sipURI)
        }else{
            let set = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_+().").inverted
            
            for k in keys {
                guard let key = k as? NSString else {
                    LogManager.shared.log("Error : Invalid key type other than string. Code flow is returing from here.", level: .error)
                    LogManager.shared.infoLogs(log: "Outgoing | call failed: Invalid key type other than string. Code flow is returing from here.")
                    return false
                }
                guard let value = extraHeaders[key] as? NSString else {
                    LogManager.shared.log("Error : Invalid value type other than string. Code flow is returing from here.", level: .error)
                    LogManager.shared.infoLogs(log: "Outgoing | call failed: Invalid value type other than string. Code flow is returing from here.")
                    return false
                }
                
                if (key.uppercased.rangeOfCharacter(from: set) != nil) || (value.uppercased.rangeOfCharacter(from: set) != nil){
                    LogManager.shared.log("Error in call with Headers: \(key) \(value) contains characters that aren't allowed", level: .error)
                    LogManager.shared.infoLogs(log: "Outgoing | call failed: \(key) \(value) contains characters that aren't allowed")
                    continue
                }
                
                if (key.uppercased.hasPrefix("X-PH") || key.uppercased.hasPrefix("X-PLIVO")) && (key.length <= 24) {
                    continue
                }else{
                    LogManager.shared.log("Error in call with Headers: Skipping \(key) \(value)", level: .error)
                    LogManager.shared.infoLogs(log: "Outgoing | call failed: Skipping \(key) \(value)")
                    return false
                }
            }
            
            callUri = sipURI.fixedSipUri
            
            if (callUri?.count ?? 0) < 0{
                LogManager.shared.log("\(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)", level: .error)
                LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)")
                return false
            }
            self.headers = extraHeaders
            if callUri!.isAlphanumeric == true || (callUri!.hasPrefix("+") && callUri!.removingPrefix("+").isNumeric)  || callUri!.contains("_") {
                self.state = .Dialing
                LogManager.shared.log("Making call with Headers passed all checks", level: .debug)
                self.initiateWebrtcCall(isIceRestartRequired: false, headers: extraHeaders)
                return true
            }else{
                LogManager.shared.log("\(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)", level: .error)
                LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)")
                return false
            }
        }
    }
    
    /// Calling this method on the PlivoOutgoing object with the SIP URI would initiate an outbound call with custom SIP headers.
    /// - Parameters:
    ///   - sipURI: sipURI
    ///   - headers: headers
    ///   - error: error
    @objc public func call(_ sipURI: String, headers: [AnyHashable : Any], error: UnsafeMutablePointer<NSError?>) -> Bool{
        LogManager.shared.infoLogs(log: "Outgoing | call initiated with header: \(headers)")
        var extraHeaders = headers
        if !self.jwtToken.isEmpty {
            extraHeaders["X-Plivo-Jwt"] = self.jwtToken
        }
        
        if Utils.IS_CALL_RUNNING{
            LogManager.shared.log("\(Constant.ALREADY_ONE_ACTIVE_CALL) \(sipURI)", level: .error)
            LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.ALREADY_ONE_ACTIVE_CALL)")
            return false
        }
        
        var header_length = 0
        // Custom Headers
        let keys = extraHeaders.keys
        header_length = Int(keys.count )
        
        if header_length == 0 {
            LogManager.shared.log(Constant.ERROR_IN_CALL_WITH_HEADERS_NO_HEADER, level :.error)
            LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.ERROR_IN_CALL_WITH_HEADERS_NO_HEADER)")
            return self.call(sipURI)
        }else{
            let set = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_+().").inverted
            
            for k in keys {
                guard let key = k as? NSString else {
                    LogManager.shared.log("Error : Invalid key type other than string. Code flow is returing from here.", level: .error)
                    LogManager.shared.infoLogs(log: "Outgoing | call failed: Invalid key type other than string. Code flow is returing from here.")
                    return false
                }
                guard let value = extraHeaders[key] as? NSString else {
                    LogManager.shared.log("Error : Invalid value type other than string. Code flow is returing from here.", level: .error)
                    LogManager.shared.infoLogs(log: "Outgoing | call failed: Invalid value type other than string. Code flow is returing from here.")
                    return false
                }
                
                if (key.uppercased.rangeOfCharacter(from: set) != nil) || (value.uppercased.rangeOfCharacter(from: set) != nil){
                    LogManager.shared.log("Error in call with Headers: \(key) \(value) contains characters that aren't allowed", level: .error)
                    LogManager.shared.infoLogs(log: "Outgoing | call failed: \(key) \(value) contains characters that aren't allowed")
                    continue
                }
                
                if (key.uppercased.hasPrefix("X-PH") || key.uppercased.hasPrefix("X-PLIVO")) && (key.length <= 24) {
                    continue
                }else{
                    LogManager.shared.log("Error in call with Headers: Skipping \(key) \(value)", level: .error)
                    LogManager.shared.infoLogs(log: "Outgoing | call failed: Skipping \(key) \(value)")
                    return false
                }
            }
            
            callUri = sipURI.fixedSipUri
            
            if (callUri?.count ?? 0) < 0{
                LogManager.shared.log("\(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)", level: .error)
                LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)")
                if error != nil {
                    let domain = Environment.bundleId
                    let desc = Constant.EMPTY_URI
                    let userInfo = [NSLocalizedDescriptionKey: desc]
                    error.pointee = NSError(domain: domain, code: 298, userInfo: userInfo)
                }
                return false
            }
            self.headers = extraHeaders
            if callUri!.isAlphanumeric == true || (callUri!.hasPrefix("+") && callUri!.removingPrefix("+").isNumeric) || callUri!.contains("_"){
                self.state = .Dialing
                LogManager.shared.log("Making call with Headers passed all checks", level: .debug)
                self.initiateWebrtcCall(isIceRestartRequired: false, headers: extraHeaders)
                return true
            }else{
                LogManager.shared.log("\(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)", level: .error)
                LogManager.shared.infoLogs(log: "Outgoing | call failed: \(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)")
                if error != nil {
                    let domain = Environment.bundleId
                    let desc = Constant.EMPTY_URI
                    let userInfo = [NSLocalizedDescriptionKey: desc]
                    error.pointee = NSError(domain: domain, code: 298, userInfo: userInfo)
                }
                return false
            }
        }
    }
    
    func initiateWebrtcCall(isIceRestartRequired:Bool, headers:[AnyHashable : Any]?){
        if let customHeaders = headers{
            webrtcAdapter?.sendOffer(isIceRestartRequired: isIceRestartRequired, headers: customHeaders)
        }else{
            webrtcAdapter?.sendOffer(isIceRestartRequired: isIceRestartRequired)
        }
    }
    
    ///Calling this method on the PlivoIncoming object with the digits would send DTMF on that call.
    /// - Parameter digits: DTMF digit
    @objc public func sendDigits(_ digits: String)-> Bool {
        if state != .Ongoing {
            LogManager.shared.infoLogs(log: "Outgoing | Error in sending digits: there is no active call now: \(digits)")
            return false
        }
        if isHold {
            LogManager.shared.infoLogs(log: "Outgoing | Error in sending digits: call is on hold: \(digits)");
            return false;
        }
        if (digits.count) > 24 {
            LogManager.shared.infoLogs(log: "Outgoing | \(Constant.ERROR_IN_SENDING_DIGIT): \(digits)")
            return false
        }
        if !checkDtmfDigit(digits) {
            LogManager.shared.infoLogs(log: "Outgoing | \(Constant.ERROR_IN_SENDING_INVALID_DIGIT)  \(digits)")
            return false
        }
        LogManager.shared.infoLogs(log: "Outgoing | dtmf send: \(digits)")
        webrtcAdapter?.sendDigits(digits: digits)
        return true
    }
    
    // calling this method to check if valid DTMF is sent
    func checkDtmfDigit(_ digit: String) -> Bool {
        let validDtmf: Set<String> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "#"]
        return validDtmf.contains(digit)
    }

    
    //Done
    /// Calling this method on the PlivoOutgoing object would disconnect the call.
    @available(*, deprecated, message: "This method is deprecated, please use 'hangup'")
    @objc public func disconnect() {
        self.hangup()
    }
    
    //Done
    ///Calling this method on the PlivoIncoming object would disconnect the call.
    @objc public func hangup(){
        state = .Terminated
        self.headers = nil
        LogManager.shared.infoLogs(log: "Outgoing | call hangup() initiated locally")
        stopSpeechRecognition()
        self.webrtcAdapter?.hangupCall()
        self.sipAdapter?.hangupSession()
        LogManager.shared.log("Call hangup requested from App", level: .debug)
    }
    
    //Done
    /// Calling this method on the PlivoIncoming object would mute the call.
    @objc public func mute(){
        if self.state == .Ongoing {
            self.webrtcAdapter?.mute()
            isMute = true
            self.startSpeechRecognition()
            LogManager.shared.infoLogs(log: "Outgoing | call Muted")
            self.sendStatsOnSocket("mute", Constant.TOGGLE_MUTE)
        } else {
            LogManager.shared.infoLogs(log: "Outgoing | Can't mute, Call not answered")
        }
    }
    
    //Done
    /// Calling this method on the PlivoIncoming object would unmute the call.
    @objc public func unmute(){
        self.webrtcAdapter?.unmute()
        self.stopSpeechRecognition()
        isMute = false
        LogManager.shared.infoLogs(log: "Outgoing | call Unmuted")
        self.sendStatsOnSocket("unmute", Constant.TOGGLE_MUTE)
    }
    
    
    /// Calling this method on the PlivoIncoming object would disconnect the audio devices during audio interruption.
    @objc public func hold(){
        if state != .Ongoing {
            LogManager.shared.log("Error in holding call: call is not active", level:.error)
            return
        }
        LogManager.shared.infoLogs(log: "Outgoing | call on hold")
        self.webrtcAdapter?.hold()
        isHold = true
        self.sendStatsOnSocket("hold", Constant.TOGGLE_HOLD)
    }
    
    /// Calling this method on the PlivoIncoming object would reconnect the audio devices after audio interruption.
    @objc public func unhold(){
        if state != .Ongoing {
            LogManager.shared.log("Error in unholding call: call is not active", level: .error)
            return
        }
        isHold = false
        LogManager.shared.infoLogs(log: "Outgoing | call unhold")
        self.webrtcAdapter?.unhold()
        
        self.sendStatsOnSocket("unhold", Constant.TOGGLE_HOLD)
    }
    
    @objc private func sendStatsOnSocket(_ action: String, _ msg: String) {
        guard let rtpStat = rtpStats else { LogManager.shared.log("sendStatsOnSocket()  RTPStats object is nil for action: \(action)", level:.error); return }
        var statsDict = rtpStat.getInitialStats(isCallAnswered: true)
        statsDict["action"] = action;
        statsDict["msg"] = msg;
        self.feedbackManager?.sendStats(statsDict: &statsDict, type: msg)
    }
    
}





extension PlivoOutgoing:WebrtcAdapterOutgoingDelegate{
    
    func onIceCandidate(sdp: String, sdpMid: String) {
        self.sipAdapter?.onIceCandidate(sdp, andMid: sdpMid)
    }
    
    func onIceGatheringFinish() {
        self.sipAdapter?.onIceGatheringFinished()
    }
    
    
    func sendOffer(localSDP: String) {
        LogManager.shared.log(" webrtcAdapter?.sendOffer \(localSDP) sipUri : \(callUri ?? "NIL") ", level: .info)
        self.sipAdapter?.makeCall(to: callUri, andLocalSdp: localSDP)
    }
    
    func sendOffer(localSDP: String, headers: [AnyHashable : Any]) {
        LogManager.shared.log(" webrtcAdapter?.sendOffer with headers \(localSDP) sipUri : \(callUri ?? "NIL") headers : \(headers)", level: .info)
        self.sipAdapter?.makeCall(to: callUri, andLocalSdp: localSDP, andHeaders: headers)
    }
    
}
