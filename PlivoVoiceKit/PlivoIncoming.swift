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
    
    public override init() {
        super.init()
        LogManager.shared.log("init PlivoIncoming", level: .debug)
        //TODO: Reset call id
    }
    
    convenience init(sipAdapter:SipAdapter, webrtcAdapter:WebrtcAdapter) {
        self.init()
        LogManager.shared.log("init PlivoIncoming with webrtc and sip object", level: .debug)
        self.sipAdapter = sipAdapter
        self.webrtcAdapter = webrtcAdapter
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
        
        if let sdp = self.localSdp{
            LogManager.shared.log("User accepted call with sdp", level: .debug)
            StatsConfig.answer_time = Utils.getCurrentTimeInMilliSeconds()
            self.sipAdapter?.answer(sdp)
        }else{
            LogManager.shared.log("User accepted call but sdp is not yet ready \(self)", level: .debug)
        }
        
        //TODO: Check pjsip callid logic
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
        self.webrtcAdapter?.mute()
    }
    
    /// Calling this method on the PlivoIncoming object would unmute the call.
    @objc public func unmute(){
        self.webrtcAdapter?.unmute()
    }
    
    ///Calling this method on the PlivoIncoming object with the digits would send DTMF on that call.
    /// - Parameter digits: DTMF digit
    @objc public func sendDigits(_ digits: String) {
        if state != .Ongoing {
            LogManager.shared.log("Error in sending digits: there is no active call now", level : .error)
            return
        }
        if (digits.count) > 24 {
            LogManager.shared.log(Constant.ERROR_IN_SENDING_DIGIT, level : .error)
            return
        }
        
        webrtcAdapter?.sendDigits(digits: digits)
    }
    
    ///Calling this method on the PlivoIncoming object would disconnect the call.
    @objc public func hangup(){
        //TODO: Check old logic for pjsipcall id
        LogManager.shared.log("Hangup call called in incoming", level: .debug)
        self.state = .Terminated
        self.webrtcAdapter?.hangupCall()
        self.sipAdapter?.hangupSession()
        //TODO: check this pjsua_call_hangup(pjsipCallId, 0, NULL, NULL);
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
        self.sipAdapter?.rejectCall()
        self.webrtcAdapter?.hangupCall()
//        }else{
//            self.hangup()
//        }
        
        self.state = .Terminated
    }
    
    /// Calling this method on the PlivoIncoming object would disconnect the audio devices during audio interruption.
    @objc public func hold(){
        self.webrtcAdapter?.hold()
    }
    
    /// Calling this method on the PlivoIncoming object would reconnect the audio devices after audio interruption.
    @objc public func unhold(){
        self.webrtcAdapter?.unhold()
    }
    
}
