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
    private var callUri:String?
    var headers:[AnyHashable:Any]?
    
    public override init() {
        super.init()
        self.callId = ""
    }
    
    convenience init(sipAdapter:SipAdapter, webrtcAdapter:WebrtcAdapter) {
        self.init()
        LogManager.shared.log("init PlivoOutgoing", level: .debug)
        self.sipAdapter = sipAdapter
        self.webrtcAdapter = webrtcAdapter
        self.webrtcAdapter?.outgoingDelegate = self
    }
    
    deinit {
        LogManager.shared.log("deinit PlivoOutgoing", level: .debug)
    }
    
    /// Calling this method on the PlivoOutgoing object with the SIP URI would initiate an outbound call.
    /// - Parameter sipURI: sipURI
    @objc public func call(_ sipURI: String) {
        if Utils.IS_CALL_RUNNING{
            LogManager.shared.log("\(Constant.ALREADY_ONE_ACTIVE_CALL) \(sipURI)", level: .error)
            return
        }
        
        callUri = sipURI.fixedSipUri
        
        if (callUri?.count ?? 0) < 0{
            LogManager.shared.log("\(Constant.INVALID_SIP_URI) \(sipURI)", level: .error)
            return
        }
        
        if callUri!.isAlphanumeric == true || (callUri!.hasPrefix("+") && callUri!.removingPrefix("+").isNumeric){
            self.state = .Dialing
            self.initiateWebrtcCall(isIceRestartRequired: false, headers: nil)
        }else{
            LogManager.shared.log("\(Constant.INVALID_SIP_URI) \(sipURI)", level: .error)
            return
        }
       
    }
    
    /// Calling this method on the PlivoOutgoing object with the SIP URI would initiate an outbound call.
    /// - Parameters:
    ///   - sipURI: sipURI
    ///   - error: error
    @objc public func call(_ sipURI: String, error: UnsafeMutablePointer<NSError>?) {
        
        if Utils.IS_CALL_RUNNING{
            LogManager.shared.log("\(Constant.ALREADY_ONE_ACTIVE_CALL) \(sipURI)", level: .error)
            return
        }
        
        callUri = sipURI.fixedSipUri
        
        if (callUri?.count ?? 0) < 0{
            LogManager.shared.log("\((Constant.INVALID_SIP_URI)) \(sipURI)", level: .error)
            if error != nil {
                let domain = Environment.bundleId
                let desc = Constant.EMPTY_URI
                let userInfo = [
                    NSLocalizedDescriptionKey: desc
                ]
                
                error?.pointee = NSError(domain: domain, code: 298, userInfo: userInfo)
            }
            return
        }
        
        if callUri!.isAlphanumeric == true || (callUri!.hasPrefix("+") && callUri!.removingPrefix("+").isNumeric){
            self.state = .Dialing
            self.initiateWebrtcCall(isIceRestartRequired: false, headers: nil)
        }else{
            LogManager.shared.log("\((Constant.INVALID_SIP_URI)) \(sipURI)", level: .error)
            if error != nil {
                let domain = Environment.bundleId
                let desc = Constant.EMPTY_URI
                let userInfo = [
                    NSLocalizedDescriptionKey: desc
                ]
                
                error?.pointee = NSError(domain: domain, code: 298, userInfo: userInfo)
            }
            return
        }
    }
    
    /// Calling this method on the PlivoOutgoing object with the SIP URI would initiate an outbound call with custom SIP headers.
    /// - Parameters:
    ///   - sipURI: sipURI
    ///   - headers: headers
    @objc public func call(_ sipURI: String, headers: [AnyHashable : Any]) {
        
        if Utils.IS_CALL_RUNNING{
            LogManager.shared.log("\(Constant.ALREADY_ONE_ACTIVE_CALL) \(sipURI)", level: .error)
            return
        }
        
        var header_length = 0
        // Custom Headers
        let keys = headers.keys
        header_length = Int(keys.count )
        
        if header_length == 0 {
            LogManager.shared.log(Constant.ERROR_IN_CALL_WITH_HEADERS_NO_HEADER, level :.error)
            self.call(sipURI)
        }else{
            let set = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_+()").inverted
            
            for k in keys {
                guard let key = k as? NSString else {
                    LogManager.shared.log("Error : Invalid key type other than string. Code flow is returing from here.", level: .error)
                    return
                }
                guard let value = headers[key] as? NSString else {
                    LogManager.shared.log("Error : Invalid value type other than string. Code flow is returing from here.", level: .error)
                    return
                }
                
                if (key.uppercased.rangeOfCharacter(from: set) != nil) || (value.uppercased.rangeOfCharacter(from: set) != nil){
                    LogManager.shared.log("Error in call with Headers: \(key) \(value) contains characters that aren't allowed", level: .error)
                    continue
                }
                
                if (key.uppercased.hasPrefix("X-PH")) && (key.length <= 24) && (value.length  <= 48) {
                    continue
                }else{
                    LogManager.shared.log("Error in call with Headers: Skipping \(key) \(value)", level: .error)
                    return
                }
            }
            
            callUri = sipURI.fixedSipUri
            
            if (callUri?.count ?? 0) < 0{
                LogManager.shared.log("\(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)", level: .error)
                return
            }
            
            if callUri!.isAlphanumeric == true || (callUri!.hasPrefix("+") && callUri!.removingPrefix("+").isNumeric){
                self.state = .Dialing
                LogManager.shared.log("Making call with Headers passed all checks", level: .debug)
                self.initiateWebrtcCall(isIceRestartRequired: false, headers: headers)
            }else{
                LogManager.shared.log("\(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)", level: .error)
                return
            }
        }
    }
    
    /// Calling this method on the PlivoOutgoing object with the SIP URI would initiate an outbound call with custom SIP headers.
    /// - Parameters:
    ///   - sipURI: sipURI
    ///   - headers: headers
    ///   - error: error
    @objc public func call(_ sipURI: String, headers: [AnyHashable : Any], error: UnsafeMutablePointer<NSError?>) {
        
        if Utils.IS_CALL_RUNNING{
            LogManager.shared.log("\(Constant.ALREADY_ONE_ACTIVE_CALL) \(sipURI)", level: .error)
            return
        }
        
        var header_length = 0
        // Custom Headers
        let keys = headers.keys
        header_length = Int(keys.count )
        
        if header_length == 0 {
            LogManager.shared.log(Constant.ERROR_IN_CALL_WITH_HEADERS_NO_HEADER, level :.error)
            self.call(sipURI)
        }else{
            let set = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_+()").inverted
            
            for k in keys {
                guard let key = k as? NSString else {
                    LogManager.shared.log("Error : Invalid key type other than string. Code flow is returing from here.", level: .error)
                    return
                }
                guard let value = headers[key] as? NSString else {
                    LogManager.shared.log("Error : Invalid value type other than string. Code flow is returing from here.", level: .error)
                    return
                }
                
                if (key.uppercased.rangeOfCharacter(from: set) != nil) || (value.uppercased.rangeOfCharacter(from: set) != nil){
                    LogManager.shared.log("Error in call with Headers: \(key) \(value) contains characters that aren't allowed", level: .error)
                    continue
                }
                
                if (key.uppercased.hasPrefix("X-PH")) && (key.length <= 24) && (value.length  <= 48) {
                    continue
                }else{
                    LogManager.shared.log("Error in call with Headers: Skipping \(key) \(value)", level: .error)
                }
            }
            
            callUri = sipURI.fixedSipUri
            
            if (callUri?.count ?? 0) < 0{
                LogManager.shared.log("\(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)", level: .error)
                if error != nil {
                    let domain = Environment.bundleId
                    let desc = Constant.EMPTY_URI
                    let userInfo = [NSLocalizedDescriptionKey: desc]
                    error.pointee = NSError(domain: domain, code: 298, userInfo: userInfo)
                }
                return
            }
            
            if callUri!.isAlphanumeric == true || (callUri!.hasPrefix("+") && callUri!.removingPrefix("+").isNumeric){
                self.state = .Dialing
                LogManager.shared.log("Making call with Headers passed all checks", level: .debug)
                self.initiateWebrtcCall(isIceRestartRequired: false, headers: headers)
            }else{
                LogManager.shared.log("\(Constant.ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI) \(sipURI)", level: .error)
                if error != nil {
                    let domain = Environment.bundleId
                    let desc = Constant.EMPTY_URI
                    let userInfo = [NSLocalizedDescriptionKey: desc]
                    error.pointee = NSError(domain: domain, code: 298, userInfo: userInfo)
                }
                return
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
        self.webrtcAdapter?.hangupCall()
        self.sipAdapter?.hangupSession()
        LogManager.shared.log("Call hangup requested from App", level: .debug)
    }
    
    //Done
    /// Calling this method on the PlivoIncoming object would mute the call.
    @objc public func mute(){
        self.webrtcAdapter?.mute()
    }
    
    //Done
    /// Calling this method on the PlivoIncoming object would unmute the call.
    @objc public func unmute(){
        self.webrtcAdapter?.unmute()
    }
    
    
    /// Calling this method on the PlivoIncoming object would disconnect the audio devices during audio interruption.
    @objc public func hold(){
        if state != .Ongoing {
            LogManager.shared.log("Error in holding call: call is not active", level:.error)
            return
        }
        
        self.webrtcAdapter?.hold()
    }
    
    /// Calling this method on the PlivoIncoming object would reconnect the audio devices after audio interruption.
    @objc public func unhold(){
        if state != .Ongoing {
            LogManager.shared.log("Error in unholding call: call is not active", level: .error)
            return
        }
        
        self.webrtcAdapter?.unhold()
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
