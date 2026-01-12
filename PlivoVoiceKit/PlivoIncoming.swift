//
//  PlivoIncoming.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 02/02/21.
//

import Foundation

protocol PlivoIncomingDelegate {
    func triggerOnIncomingCallInvalidNotification()
}

@objc public class PlivoIncoming: NSObject {
    
    /// The accId of the registered Endpoint
    public var accId:PlivoAccId?
    
    /// The callId of the call
    @objc public var callId:PlivoCallId?
    
    /// The number/SIP URI from which the call is being received
    @objc public var fromContact:String = ""
    
    /// The SIP URI on which the call is being received
    @objc public var toContact:String = ""
    
    /// The SIP User For Display
    @objc public var fromUser:String = ""
    
    @objc public var stirVerification:String = "Not applicable"
    
    /// State of the call
    public internal(set) var state:PlivoCallState?
    
    /// Extra headers
    public var extraHeaders = [AnyHashable: Any]() {
        didSet{
            stirVerification = extraHeaders["X-Plivo-Stir-Verification"] as? String ?? "Not applicable"
        }
    }
    
    private var incomingInviteTimer:Timer?
    
    var delegate:PlivoIncomingDelegate?
    
    private var sipAdapter:SipAdapter?
    private var webrtcAdapter: WebrtcAdapter?
    var localSdp:String?
    var isCallAnswered = false
    var isHold = false;
    var isMute = false;
    private var feedbackManager: FeedbackManager?
    var rtpStats: RtpStats?
    var speechTimer: Timer?

    
    public override init() {
        super.init()
        LogManager.shared.log("init PlivoIncoming", level: .debug)
        //TODO: Reset call id
    }
    
    convenience init(sipAdapter:SipAdapter, webrtcAdapter:WebrtcAdapter, feedbackManager: FeedbackManager, rtpStats: RtpStats) {
        self.init()
        LogManager.shared.log("init PlivoIncoming with webrtc and sip object", level: .debug)
        self.sipAdapter = sipAdapter
        self.webrtcAdapter = webrtcAdapter
        self.feedbackManager = feedbackManager
        self.rtpStats = rtpStats
    }
    
    deinit {
        LogManager.shared.log("deinit PlivoIncoming", level: .debug)
    }
    
    
    /// Calling this method on the PlivoIncoming object would answer the call.
    @objc public func answer(){
        LogManager.shared.log("answer() from user", level: .debug)
        
        if self.callId?.count == 0{
            LogManager.shared.log("Returning from here : Call id not present. Trying answer in on_incoming_call", level: .error)
            Utils.setAnswerFlag(true)
            
            self.incomingInviteTimer = Timer.scheduledTimer(timeInterval: Constant.ANSWER_INVITE_CHECK_INTERVAL, target: self, selector: #selector(checkIncomingInviteTimer), userInfo: nil, repeats: false)
            LogManager.shared.log("Invite timer started in answer state", level: .debug)
            return
        }
        
        isCallAnswered = true
        self.webrtcAdapter?.createAnswer() { (localSDP) in
            LogManager.shared.log("User accepted call with sdp", level: .debug)
            StatsConfig.answer_time = Utils.getCurrentTimeInMilliSeconds()
            LogManager.shared.infoLogs(log: "Incoming | SDP Answer created: \(localSDP)")
            self.sipAdapter?.answer(localSDP)
        }
    }
    
    @objc private func checkIncomingInviteTimer(){
        LogManager.shared.log("Checking Incoming Invite in answer state", level: .debug)
        if !Utils.getInviteFlag(){
            LogManager.shared.log("Invite did not come after \(Constant.ANSWER_INVITE_CHECK_INTERVAL) seconds in answer state", level: .debug)
            self.delegate?.triggerOnIncomingCallInvalidNotification()
        }
        self.incomingInviteTimer?.invalidate()
        self.incomingInviteTimer = nil
    }
    
    /// Calling this method on the PlivoIncoming object would mute the call.
    @objc public func mute(){
        if self.state == .Ongoing {
            self.webrtcAdapter?.mute()
            isMute = true;
            self.startSpeechRecognition()
            LogManager.shared.infoLogs(log: "Incoming | call muted")
            self.sendStatsOnSocket("mute", Constant.TOGGLE_MUTE)
        } else {
            LogManager.shared.infoLogs(log: "Incoming | Can't mute, Call not answered")
        }
    }
    
    /// Calling this method on the PlivoIncoming object would unmute the call.
    @objc public func unmute(){
        self.webrtcAdapter?.unmute()
        self.stopSpeechRecognition()
        isMute = false;
        LogManager.shared.infoLogs(log: "Incoming | call unmuted")
        self.sendStatsOnSocket("unmute", Constant.TOGGLE_MUTE)
    }
    
    ///Calling this method on the PlivoIncoming object with the digits would send DTMF on that call.
    /// - Parameter digits: DTMF digit
    @objc public func sendDigits(_ digits: String) -> Bool{
        if state != .Ongoing {
            LogManager.shared.infoLogs(log: "Incoming | Error in sending digits: there is no active call now: \(digits)")
            return false
        }
        if isHold {
            LogManager.shared.infoLogs(log: "Incoming | Error in sending digits: call is on hold: \(digits)");
            return false;
        }
        if (digits.count) > 24 {
            LogManager.shared.infoLogs(log: "Incoming | \(Constant.ERROR_IN_SENDING_DIGIT): \(digits)")
            return false
        }
        if !checkDtmfDigit(digits) {
            LogManager.shared.infoLogs(log: "Incoming | \(Constant.ERROR_IN_SENDING_INVALID_DIGIT)  \(digits)")
            return false
        }
        LogManager.shared.infoLogs(log: "Incoming | dtmf send: \(digits)")
        webrtcAdapter?.sendDigits(digits: digits)
        return true
    }
    
    // calling this method to check if valid DTMF is sent
    func checkDtmfDigit(_ digit: String) -> Bool {
        let validDtmf: Set<String> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "#"]
        return validDtmf.contains(digit)
    }
    
    ///Calling this method on the PlivoIncoming object would disconnect the call.
    @objc public func hangup(){
        //TODO: Check old logic for pjsipcall id
        self.stopSpeechRecognition()
        LogManager.shared.infoLogs(log: "Incoming | Call hangup() Initiated locally")
        LogManager.shared.log("Hangup call called in incoming", level: .debug)
        self.state = .Terminated
        self.webrtcAdapter?.hangupCall()
        self.sipAdapter?.hangupSession()
        //TODO: check this pjsua_call_hangup(pjsipCallId, 0, NULL, NULL);
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
    
    ///Calling this method on the PlivoIncoming object would reject the call.
    @objc public func reject(){
        if self.callId?.count == 0{
            LogManager.shared.log("Returning from here : Call id not present. Trying reject in on_incoming_call", level: .error)
            Utils.setRejectFlag(true)
            return
        }
        LogManager.shared.log("Rejct called in incoming \(sipAdapter == nil)")
//        if self.state == .Ringing{
        LogManager.shared.infoLogs(log: "Incoming | call reject() initiated locally")
        self.sipAdapter?.rejectCall()
        self.webrtcAdapter?.hangupCall()
//        }else{
//            self.hangup()
//        }
        
        self.state = .Terminated
    }
    
    /// Calling this method on the PlivoIncoming object would disconnect the audio devices during audio interruption.
    @objc public func hold(){
        isHold = true;
        self.webrtcAdapter?.hold()
        LogManager.shared.infoLogs(log: "Incoming | call on hold")
        self.sendStatsOnSocket("hold", Constant.TOGGLE_HOLD)
    }
    
    /// Calling this method on the PlivoIncoming object would reconnect the audio devices after audio interruption.
    @objc public func unhold(){
        isHold = false;
        self.webrtcAdapter?.unhold()
        LogManager.shared.infoLogs(log: "Incoming | call on unhold")
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
