//
//  PlivoEndpoint.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 02/02/21.
//

import Foundation
import AVFoundation
//import Connectivity

public class PlivoEndpoint: NSObject {
    
    private var initOptions : [AnyHashable : Any]
    
    private var accId:Int?
    private var callId:String?
    private var callData:String?
    
    private var apnsPayload:[AnyHashable : Any]?
    
    private var isSipToSipInvite = true
    private var isInvalidInvite = false
    private var ringTimer:Timer?
    private var logTimer:Timer?
    private var audioTimer:Timer?
    private var statsTimer:Timer?
    
    private var curIncomingCall:PlivoIncoming?
    private var curOutCall:PlivoOutgoing?
    
    @objc public var delegate:AnyObject?
    
    private var lastNetworkChange:Date?
    
    private let reachability = try? Reachability()
    
    private var feedbackManager:FeedbackManager?
    
    private var sipClient:SipAdapter?
    private var webrtcAdapter = WebrtcAdapter()
    
    private var rtpStats:RtpStats?
    
    private let hostNames = [nil, "google.com", "invalidhost"]
    private let MAX_ENDPOINT_LENGTH        =     212
    
    private var isIncomingCall = false
    
    private var isRegistered = false
    
    private var isApplicationinBackground = false
    
    private override init() {
        self.initOptions = [AnyHashable : Any]()
        self.initOptions["enableTracking"] = true
        lastNetworkChange = Date()
    }
    
    @available(*, deprecated, message: "'initWithDebug:isDebug' is deprecated. Use `init:initOptions` or `init:` instead")
    private convenience init?(debug isDebug: Bool) {
        self.init()
        LogManager.shared.log("default init(isDebug: Bool) method invoked", level: .debug)
    }
    
    @objc public convenience init(_ options: [AnyHashable : Any]) {
        self.init(debug: options["debug"] as? Bool ?? false, options)
        LogManager.shared.log("default init(options:[AnyHashable : Any]) method invoked", level: .debug)
        
        self.initOptions = [AnyHashable : Any]()
        initOptions["debug"] = false
        initOptions["enableTracking"] = true
        
        if let isEnableTracking = options["enableTracking"] as? Bool{
            initOptions["enableTracking"] = isEnableTracking
        }
        
        if let isDebugEnabled = options["debug"] as? Bool{
            initOptions["debug"] = isDebugEnabled
        }
        
        self.feedbackManager = FeedbackManager()
        self.sipClient = SipAdapter()
        self.rtpStats = RtpStats()
        self.rtpStats?.delegate = self
        self.sipClientEventHandler()
    }
    
    @available(*, deprecated, message: "'initWithDebug:isDebug:initOptions' is deprecated. Use `init:initOptions` or `init:` instead")
    @objc public convenience init(debug isDebug: Bool, _ options: [AnyHashable : Any]) {
        self.init()
        LogManager.shared.log("default init(isDebug: Bool, _ options: [AnyHashable : Any]) method invoked", level: .debug)
        
        initOptions["enableTracking"] = true
        if let enableTracking = options["enableTracking"] as? Bool {
            initOptions["enableTracking"] = enableTracking
        }
        
        self.checkBitrate(options)
        
        var isDebugEnable = false
        if let debug = options["debug"] as? Bool {
            isDebugEnable = debug
        }
        
        initOptions["debug"] = isDebugEnable
        
        if self.sipClient == nil{
            self.feedbackManager = FeedbackManager()
            self.sipClient = SipAdapter()
            self.rtpStats = RtpStats()
            self.rtpStats?.delegate = self
            self.sipClientEventHandler()
        }
        
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIScene.willDeactivateNotification, object: nil)
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.willResignActiveNotification, object: nil)
        }
        
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIScene.didActivateNotification, object: nil)
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(dumpLog(_:)), name: NSNotification.Name("log_dump"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .reachabilityChanged, object: reachability)
        do{
            try reachability?.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }
    }
    
    @objc func applicationDidEnterBackground(_ notification:Notification){
        self.isApplicationinBackground = true
        
        LogManager.shared.log("SDK applicationDidEnterBackground \(String(describing: curIncomingCall))")
        
        if (curOutCall?.state == .Ongoing || curOutCall?.state == .Ringing || curOutCall?.state == .Dialing){
            LogManager.shared.log("In ongoing call returing from here", level: .debug)
            return
        }
        
        if (curIncomingCall?.state == .Ongoing || curIncomingCall?.state == .Ringing || curIncomingCall?.state == .Dialing){
            LogManager.shared.log("In ongoing call returing from here", level: .debug)
            return
        }
        
        if let incoming = curIncomingCall{
            LogManager.shared.log("SDKDidEnterBackground hanging up incoming call", level: .debug)
            self.delegate?.onIncomingCallRejected?(incoming)
            incoming.hangup()
        }
        
        if let outgoing = curOutCall{
            LogManager.shared.log("SDKDidEnterBackground hanging up outgoing call", level: .debug)
            self.delegate?.onOutgoingCallRejected?(outgoing)
            outgoing.hangup()
        }
        
        self.resetEndpoint()
    }
    
    @objc func applicationWillEnterForeground(_ notification:Notification){
        self.isApplicationinBackground = false
        
        LogManager.shared.log("SDK applicationWillEnterForeground \(String(describing: curOutCall?.state?.rawValue)) \(String(describing: curIncomingCall?.state))")
        
        if (curOutCall?.state == .Ongoing || curOutCall?.state == .Ringing || curOutCall?.state == .Dialing){
            LogManager.shared.log("In ongoing call returing from here", level: .debug)
            return
        }
        
        if (curIncomingCall?.state == .Ongoing || curIncomingCall?.state == .Ringing || curIncomingCall?.state == .Dialing){
            LogManager.shared.log("In ongoing call returing from here", level: .debug)
            return
        }
        
        if StatsConfig.cert_id?.isEmpty == false && StatsConfig.token != nil{
            sipClient?.registerUser(withUsername: StatsConfig.username, andPassword: StatsConfig.password, andToken: StatsConfig.token, andCertificateId: StatsConfig.cert_id)
        }else if StatsConfig.token != nil{
            sipClient?.registerUser(withUsername: StatsConfig.username, andPassword: StatsConfig.password, andToken: StatsConfig.token)
        }
        
        if StatsConfig.cert_id?.isEmpty == true && StatsConfig.token == nil{
            sipClient?.registerUser(withUsername: StatsConfig.username, andPassword: StatsConfig.password)
        }
    }
    
    private func checkBitrate(_ options: [AnyHashable : Any]?) {
        initOptions["maxAverageBitrate"] = NSNumber(value: Constant.MAX_AVERAGE_BITRATE)
        if let option = options, option["maxAverageBitrate"] != nil && !(option["maxAverageBitrate"] is NSString) && !NumberIsFraction(option["maxAverageBitrate"] as? NSNumber) {
            let bitrate = UInt((options?["maxAverageBitrate"] as? NSNumber)?.uint32Value ?? 0)
            if bitrate >= Constant.MIN_AVERAGE_BITRATE && bitrate <= Constant.MAX_AVERAGE_BITRATE {
                initOptions["maxAverageBitrate"] = NSNumber(value: UInt32(bitrate))
            }
        }
    }
    
    private func NumberIsFraction(_ number: NSNumber?) -> Bool {
        let diff = number?.doubleValue ?? 0.0 - Double(number?.intValue ?? 0)
        if diff > 0 {
            return true
        } else {
            return false
        }
    }
    
    @objc private func dumpLog(_ obj: Notification){
        guard let logLevel = obj.userInfo?["LEVEL"] as? String else {return}
        guard let logValue = obj.userInfo?["LOG"] as? String else {return}
        self.delegate?.logs?(logValue, level: logLevel)
    }
    //
    
    deinit {
        LogManager.shared.log("deinit PlivoEndpoint", level: .alert)
        feedbackManager = nil
        reachability?.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }
}




extension PlivoEndpoint{
    
    @objc private func reachabilityChanged(_ status: Notification) {
        let reachability = status.object as! Reachability

        switch reachability.connection {
        case .wifi:
            LogManager.shared.log(Constant.WIFI_INTERNET, level: .info)
        case .cellular:
            LogManager.shared.log(Constant.MOBILE_INTERNET, level: .info)
        case .unavailable:
            LogManager.shared.log(Constant.NO_INTERNET, level: .info)
        }
        
        if reachability.connection != .unavailable{
            let currentTime = Date()
            let diff = currentTime.timeIntervalSince(lastNetworkChange!)
            lastNetworkChange = currentTime
            if (diff <= 5) {
                LogManager.shared.log(Constant.FREQUENT_NETWORK_CHANGE_ERROR, level:.warning)
                return
            }
            
            LogManager.shared.log(Constant.RESET_SESSION_ON_NETWORK_CHANGE, level:.info)
            
            if let outgoingCall = self.curOutCall, outgoingCall.state == .Ongoing{
                self.sipClient?.networkChange()
            }
            
            if let incomingCall = self.curIncomingCall, incomingCall.state == .Ongoing{
                self.sipClient?.networkChange()
            }
            
        }
    }
    
}



//MARK: - Public interface registration methods
extension PlivoEndpoint{
    
    /// Give users the ability to sign into plivo SIP server. With username and password
    /// - Parameters:
    ///   - username: username registered on plivo console
    ///   - password: password used to register on plivo console
    //Done
    @objc public func login(_ username: String, andPassword password: String) {
        if (username.isEmpty  || password.isEmpty) {
            LogManager.shared.log(Constant.EMPTY_LOGIN_1, level: .notice)
            
            guard let error = Utils.error(withMessage: Constant.EMPTY_LOGIN_1, code: 1111) else {
                LogManager.shared.log(Constant.FAILED_TO_CREATE_ERROR, level: .error)
                return
            }
            self.delegate?.onLoginFailed?()
            self.delegate?.onLoginFailedWithError?(error)
            LogManager.shared.log(Constant.DEBUG_LOGIN_FAILED_EVENT, level: .debug)
            return
        }
        login(username: username, password: password, token: nil, certificateId: "")
    }
    
    /// Give users the ability to sign into plivo SIP server. With timeout option
    /// - Parameters:
    ///   - username: username registered on plivo console
    ///   - password: password used to register on plivo console
    ///   - RegTimeout: registration timeout
    //Done
    @objc public func login(_ username: String, andPassword password: String, regTimeout: Int) {
        if (regTimeout < 120 || regTimeout > 86400) {
            LogManager.shared.log(Constant.REG_TIMEOUT_ERROR, level: .notice)
            
            guard let error = Utils.error(withMessage: Constant.REG_INVALID_TIMEOUT, code: Constant.REG_INVALID_TIMEOUT_CODE) else {
                LogManager.shared.log(Constant.FAILED_TO_CREATE_ERROR, level: .error)
                return
            }
            self.delegate?.onLoginFailed?()
            self.delegate?.onLoginFailedWithError?(error)
            LogManager.shared.log(Constant.DEBUG_LOGIN_FAILED_EVENT, level: .debug)
            return
        }
        
        if (username.isEmpty  || password.isEmpty) {
            LogManager.shared.log(Constant.EMPTY_LOGIN_1, level: .notice)
            
            guard let error = Utils.error(withMessage: Constant.EMPTY_LOGIN_1, code: 1111) else {
                LogManager.shared.log(Constant.FAILED_TO_CREATE_ERROR, level: .error)
                return
            }
            self.delegate?.onLoginFailed?()
            self.delegate?.onLoginFailedWithError?(error)
            LogManager.shared.log(Constant.DEBUG_LOGIN_FAILED_EVENT, level: .debug)
            return
        }
        
        Constant.registrationTimeout = regTimeout
        
        sipClient?.setRegisterTimeout(Constant.registrationTimeout as NSNumber)
        login(username: username, password: password, token: nil, certificateId: "")
    }
    
    /// Give users the ability to sign into plivo SIP server. With username, password, deviceToken
    /// - Parameters:
    ///   - username: username registered on plivo console
    ///   - password: password used to register on plivo console
    ///   - token: mobile device token
    //Done
    @objc public func login(_ username: String, andPassword password: String, deviceToken token: Data?) {
        if (username.isEmpty  || password.isEmpty || token == nil) {
            LogManager.shared.log(Constant.EMPTY_LOGIN_2, level: .notice)
            
            guard let error = Utils.error(withMessage: Constant.EMPTY_LOGIN_2, code: 1112) else {
                LogManager.shared.log(Constant.FAILED_TO_CREATE_ERROR, level: .error)
                return
            }
            self.delegate?.onLoginFailed?()
            self.delegate?.onLoginFailedWithError?(error)
            LogManager.shared.log(Constant.DEBUG_LOGIN_FAILED_EVENT, level: .debug)
            return
        }
        login(username: username, password: password, token: token, certificateId: "")
    }
    
    /// Give users the ability to sign into plivo SIP server. With username, password, deviceToken and certificateid
    /// - Parameters:
    ///   - username: username registered on plivo console
    ///   - password: password used to register on plivo console
    ///   - token: mobile device token
    ///   - CertificateId: APNS certificate id
    //Done
    @objc public func login(_ username: String, andPassword password: String, deviceToken token: Data?, certificateId: String) {
        if (username.isEmpty  || password.isEmpty || token == nil || certificateId.isEmpty) {
            LogManager.shared.log(Constant.EMPTY_LOGIN_3, level: .notice)
            
            guard let error = Utils.error(withMessage: Constant.EMPTY_LOGIN_3, code: 1112) else {
                LogManager.shared.log(Constant.FAILED_TO_CREATE_ERROR, level: .error)
                return
            }
            self.delegate?.onLoginFailed?()
            self.delegate?.onLoginFailedWithError?(error)
            LogManager.shared.log(Constant.DEBUG_LOGIN_FAILED_EVENT, level: .debug)
            return
        }
        login(username: username, password: password, token: token, certificateId: certificateId)
    }
    
    
    private func login(username: String, password: String, token: Data?, certificateId: String) {
        
        self.sipClient?.setRegisterTimeout(Constant.registrationTimeout as NSNumber)
        
        if isRegistered{
            LogManager.shared.log(Constant.ALREADY_REGISTERED, level: .warning)
            return
        }
        
        let userName = username.fixedSipUri
        
        let deviceToken = token?.hexString
        
        if (deviceToken != "") {
            LogManager.shared.log("\(String(describing: deviceToken))", level: .debug)
        }
       
        // Check for network availability
        if Utils.isNetworkAvailable() == false{
            LogManager.shared.log(Constant.NO_INTERNET, level: .notice)
            
            guard let error = Utils.error(withMessage: Constant.NO_INTERNET, code: 289) else {
                LogManager.shared.log(Constant.FAILED_TO_CREATE_ERROR, level: .error)
                return
            }
            self.delegate?.onLoginFailed?()
            self.delegate?.onLoginFailedWithError?(error)
            LogManager.shared.log(Constant.DEBUG_LOGIN_FAILED_EVENT, level: .debug)
            return
        }
        
        if(userName.count <= MAX_ENDPOINT_LENGTH && userName.count > 0) && userName.isAlphanumeric == true{
            LogManager.shared.log("username after passing all validations \(userName)", level: .debug)
            StatsConfig.username = userName
            StatsConfig.password = password
            
            //Call stats key api request required here
            rtpStats?.getCallStatsKey()
            
            if certificateId.isEmpty == false && token != nil{
                StatsConfig.token = deviceToken
                StatsConfig.cert_id = certificateId
                
                sipClient?.registerUser(withUsername: userName, andPassword: password, andToken: deviceToken, andCertificateId: certificateId)
            }else if token != nil{
                StatsConfig.token = deviceToken
                sipClient?.registerUser(withUsername: userName, andPassword: password, andToken: deviceToken)
            }
            
            if certificateId.isEmpty == true && token == nil{
                sipClient?.registerUser(withUsername: userName, andPassword: password)
            }
            
        }else{
            LogManager.shared.log(Constant.INVALID_SIP_USERNAME, level: .notice)
           
            guard let error = Utils.error(withMessage: Constant.INVALID_SIP_USERNAME, code: 291) else {
                LogManager.shared.log(Constant.FAILED_TO_CREATE_ERROR, level: .error)
                return
            }
            self.delegate?.onLoginFailed?()
            delegate?.onLoginFailedWithError?(error)
            LogManager.shared.log(Constant.DEBUG_LOGIN_FAILED_EVENT, level: .debug)
        }
    }
    
    /// Send device token in SIP header
    /// - Parameter token: device apns token
    @available(*, deprecated, message: "'registerToken:token' is deprecated. Use `login:username:password:token` instead")
    @objc public func registerToken(_ token: Data) {
        //TODO:Update device token in sip header
        let tokenBytes = token.hexString
        var extraHeaders: [AnyHashable : Any] = [:]
        
        if tokenBytes.isEmpty == false{
            extraHeaders["AppleToken"] = tokenBytes
        }
        
        extraHeaders["X-PlivoIOSSDK"] = "True"
        
        if let user = StatsConfig.username, let pass = StatsConfig.password, tokenBytes.isEmpty == false{
            LogManager.shared.log("\(StatsConfig.username) \(StatsConfig.password) \(tokenBytes.isEmpty)", level: .notice)
            sipClient?.registerUser(withUsername: user, andPassword: pass, andToken: tokenBytes, andCertificateId: "NA", andproxy: "NA", andHeaders: extraHeaders)
        }else{
            LogManager.shared.log(Constant.EMPTY_LOGIN_2, level: .notice)
            
            guard let error = Utils.error(withMessage: Constant.EMPTY_LOGIN_2, code: 1112) else {
                LogManager.shared.log(Constant.FAILED_TO_CREATE_ERROR, level: .error)
                return
            }
            self.delegate?.onLoginFailed?()
            self.delegate?.onLoginFailedWithError?(error)
            LogManager.shared.log(Constant.DEBUG_LOGIN_FAILED_EVENT, level: .debug)
        }
    }
    
    /// Description
    /// - Parameter pushinfo: pushinfo description
    @objc public func relayVoipPushNotification(_ pushinfo: [AnyHashable : Any]) {
        let state = UIApplication.shared.applicationState
        var isOngoing = false
        
        if state == .background {
            print("App in Background")
            self.isApplicationinBackground = true
        }
        
        LogManager.shared.log(Constant.PROCESSING_PUSH_INFO+pushinfo.debugDescription, level: .info)
        
        guard let sipObj = self.sipClient else {
            LogManager.shared.log(Constant.NIL_SIPOBJECT, level: .emergency)
            return
        }
        
        if let inCall = self.curIncomingCall, inCall.state == .Ringing{
            LogManager.shared.log(Constant.ALREADY_ON_RINGING_STATE, level: .warning)
            return
        }
        
        if let outCall = self.curOutCall, outCall.state == .Dialing{
            LogManager.shared.log(Constant.ALREADY_ON_DAILING_STATE, level: .warning)
            return
        }
        
        if let inCall = self.curIncomingCall, inCall.state == .Ongoing{
            LogManager.shared.log(Constant.ALREADY_ONE_ACTIVE_CALL, level: .debug)
            isOngoing = true
        }
        
        if let outCall = self.curOutCall, outCall.state == .Ongoing{
            LogManager.shared.log(Constant.ALREADY_ONE_ACTIVE_CALL, level: .debug)
            isOngoing = true
        }
            
        let dic = pushinfo["aps"] as? [AnyHashable : Any]
        if dic == nil {
            return
        }
        
        let label = dic?["label"] as? String
        let stir = dic?["X-Plivo-Stir-Verification"] as? String
        let index = dic?["index"] as? String
        let registrar = dic?["registrar"] as? String
        var from = dic?["callerID"] as? String
        from = from?.replacingOccurrences(of: " ", with: "+")
        
        var extraHeaders: [AnyHashable : Any] = [:]
        let extraHeaderString = dic?["extraHeaders"] as? String
        if (extraHeaderString?.count ?? 0) != 0 {
            let extraHeaderArray = extraHeaderString?.components(separatedBy: "&")
            for eachHeader in extraHeaderArray ?? [] {
                let range = (eachHeader as NSString).range(of: ":")
                extraHeaders[(eachHeader as NSString).substring(to: range.location)] = (eachHeader as NSString).substring(from: range.location)
            }
        }
        
        extraHeaders["X-Label"] = label
        extraHeaders["X-Index"] = index
        extraHeaders["X-Plivo-Stir-Verification"] = stir
        
        if isOngoing == false{
            self.curIncomingCall = PlivoIncoming(sipAdapter: sipObj, webrtcAdapter: self.webrtcAdapter)
            self.curIncomingCall?.state = .Dialing
            self.curIncomingCall?.fromContact = from ?? "NA"
            self.curIncomingCall?.fromUser = from?.parseSipUri ?? "NA"
            self.curIncomingCall?.extraHeaders = extraHeaders
            self.curIncomingCall?.stirVerification = stir ?? "Not applicable"
            
            delegate?.onIncomingCall?(curIncomingCall!)
        }
        
        LogManager.shared.log(Constant.DEBUG_ONINCOMING_CALL_EVENT, level: .debug)
        
        if let user = StatsConfig.username, let pass = StatsConfig.password{
            sipClient?.registerUser(withUsername: user, andPassword: pass, andToken: StatsConfig.token ?? "NA", andCertificateId: StatsConfig.cert_id ?? "NA", andproxy: registrar, andHeaders: extraHeaders)
        }else{
            LogManager.shared.log(Constant.EMPTY_LOGIN_1, level: .emergency)
            
            guard let error = Utils.error(withMessage: Constant.EMPTY_LOGIN_1, code: 1111) else {
                LogManager.shared.log(Constant.FAILED_TO_CREATE_ERROR, level: .error)
                return
            }
            self.delegate?.onLoginFailed?()
            self.delegate?.onLoginFailedWithError?(error)
            LogManager.shared.log(Constant.DEBUG_LOGIN_FAILED_EVENT, level: .debug)
        }
        
        if isOngoing == false{
            Utils.setAnswerFlag(false)
            Utils.setInviteFlag(false)
            Utils.setRejectFlag(false)
            
            self.isInvalidInvite = false
            self.isSipToSipInvite = false
            
            self.ringTimer = Timer.scheduledTimer(timeInterval: Constant.RING_INVITE_CHECK_INTERVAL, target: self, selector: #selector(checkRingIncomingInviteTimer), userInfo: nil, repeats: false)
        }
        LogManager.shared.log(Constant.INVITE_TIMER_STARTED, level: .info)
    }
    
    @objc private func checkRingIncomingInviteTimer(){
        LogManager.shared.log("Checking Incoming Invite in ringing state", level: .debug)
        if Utils.getInviteFlag() == false{
            LogManager.shared.log("Invite did not come after \(Constant.RING_INVITE_CHECK_INTERVAL) seconds in ringing state", level: .debug)
            if let incomingCall = curIncomingCall{
                self.delegate?.onIncomingCallInvalid?(incomingCall)
                LogManager.shared.log(Constant.DEBUG_ONINCOMING_CALL_INVALID_EVENT, level: .debug)
            }
        }
        
        self.ringTimer?.invalidate()
        self.ringTimer = nil
    }
    
    /// Following three apis required for the apple Callkit integration. Configure audio session before the call.
    @objc public func configureAudioDevice() {
        webrtcAdapter.configureAudioSession()
    }
    
    /// Depending on the call status(Hold or Active) you’ll want to start, or stop processing the call’s audio.
    @objc public func startAudioDevice() {
        webrtcAdapter.startAudio()
    }
    
    /// Depending on the call status(Hold or Active) you’ll want to start, or stop processing the call’s audio.
    @objc public func stopAudioDevice(){
        webrtcAdapter.stopAudio()
    }
    
    /// Send Keep Alive packet while in background mode
    @objc public func keepAlive(){
        
    }
    
    /// Unregisters an endpoint , Calling this method with would unregister the SIP endpoint
    @objc public func logout(){
        //Check for all active sip registration and un register it
        LogManager.shared.log("Logout called", level: .debug)
        webrtcAdapter.hangupCall()
        sipClient?.hangupSession()
        sipClient?.unregisterUser()
        self.isRegistered = false
    }
    
}



//MARK: - Public interface call info methods
extension PlivoEndpoint{
    
    /// Description
    /// - Returns: description
    @objc public func createOutgoingCall() -> PlivoOutgoing? {
        guard let sipObj = self.sipClient else {
            LogManager.shared.log("SipClient object is nil", level: .error)
            return nil
        }
        let outGoingCall = PlivoOutgoing(sipAdapter: sipObj, webrtcAdapter: self.webrtcAdapter)
        curOutCall = outGoingCall
        return outGoingCall
    }
    
    /// Description
    /// - Returns: description
    @objc public func getLastCallUUID() -> String? {
        if StatsConfig.last_call_uuid == nil || StatsConfig.last_call_uuid == ""{
            return nil
        }
        return StatsConfig.last_call_uuid
    }
    
    /// Description
    /// - Returns: description
    @objc public func getCallUUID() -> String? {
        if StatsConfig.x_call_uuid == nil{
            return nil
        }
        return StatsConfig.x_call_uuid
    }
}




//MARK: - Internal Call management methods
extension PlivoEndpoint{
    
    fileprivate func incomingCallStates(_ otherReason: OtherReason?,_ terminateReason: TerminatedReason?, _ statusCode: Int32) {
        LogManager.shared.log("Incoming Call: status Id is: \(statusCode) otherreason \(String(describing: otherReason)) terminateReason \(String(describing: terminateReason))", level: .debug)
        // Send out all incoming notifications
        // Check if the state is disconnected and the last status code, in
        // this case, incoming reject event will be sent
        
        guard let incoming = self.curIncomingCall else {
            LogManager.shared.log("Incoming current object is nil returing from here", level: .error)
            return
        }
        
        if otherReason != nil{
            LogManager.shared.log("Incoming otherReason \(String(describing: otherReason)) \(statusCode) notifying app ", level: .debug)
            
            if (180...183).contains(statusCode){
                StatsConfig.postDialDelayEndTime = Utils.getCurrentTimeInMilliSeconds()
                StatsConfig.call_progress_time = Utils.getCurrentTimeInMilliSeconds()
                LogManager.shared.log("Incoming Call: call is ringing  status is:" + "\(statusCode)", level: .debug)
            }
            
            if otherReason == .CallAccepted{
                StatsConfig.answer_time = Utils.getCurrentTimeInMilliSeconds()
                StatsConfig.call_confirmed_time = Utils.getCurrentTimeInMilliSeconds()
                sendCallAnsweredStats(call_id: callId ?? "NA", type: Constant.INCOMING_ANSWERED_INFO)
                self.delegate?.onIncomingCallAnswered?(incoming)
                LogManager.shared.log(Constant.DEBUG_ONINCOMING_CALL_ANSWERED_EVENT, level: .debug)
            }
        }
        
        if terminateReason != nil{
            // Send incoming hangup
            LogManager.shared.log("Incoming terminateReason status code \(statusCode) ", level: .debug)
            
            if  (486...487).contains(statusCode){
                // Send incoming reject
//                PlivoIncoming *incoming = plivo_incoming_object(acc_id, call_id);
                StatsConfig.hangup_time = Utils.getCurrentTimeInMilliSeconds()
                updateLastCallUUID()
                StatsConfig.x_call_uuid = ""
                
                self.delegate?.onIncomingCallRejected?(incoming)
                LogManager.shared.log(Constant.DEBUG_ONINCOMING_CALL_REJECTED_EVENT, level: .debug)
            }
            
            if  (statusCode == 408){
                self.delegate?.onIncomingCallInvalid?(incoming)
                LogManager.shared.log(Constant.DEBUG_ONINCOMING_CALL_INVALID_EVENT, level: .debug)
            }
            
            if  statusCode == 200{
                // Send incoming hangup
//                PlivoIncoming *incoming = plivo_incoming_object(acc_id, call_id);
                StatsConfig.hangup_time = Utils.getCurrentTimeInMilliSeconds()
                updateLastCallUUID()
                StatsConfig.x_call_uuid = ""
                self.delegate?.onIncomingCallHangup?(incoming)
                LogManager.shared.log(Constant.DEBUG_ONINCOMING_CALL_HANGUP_EVENT, level: .debug)
            }
            
            if  statusCode == 603{ // 603 is self created code in resiprocate
                self.delegate?.onIncomingCallRejected?(incoming)
                LogManager.shared.log(Constant.DEBUG_ONINCOMING_CALL_REJECTED_EVENT, level: .debug)
            }
        }
    }
    
    fileprivate func outgoingCallStates(_ otherReason: OtherReason?, _ statusCode: Int32, _ terminateReason: TerminatedReason?) {
       
        if otherReason != nil{
            
            if otherReason == .Calling{
                if let out = self.curOutCall{
                    // stores outgoing call id for every call
//                    set_outgoing(call_id);
                    let outgoing:PlivoOutgoing = out
                    outgoing.state = .Dialing
                    StatsConfig.call_initiation_time = Utils.getCurrentTimeInMilliSeconds()
                    outgoing.callId = callId ?? "NA"
                    self.delegate?.onCalling?(outgoing)
                    LogManager.shared.log(Constant.DEBUG_ONOUTGOING_CALL_ONCALLING_EVENT + "\(statusCode)", level: .debug)
                }else{
                    LogManager.shared.log("Outgoing Call: call state failed because curOutCall is nil", level: .error)
                }
            }
            
            
            if (180...183).contains(statusCode){
                if let out = self.curOutCall{
                    let outgoing:PlivoOutgoing = out
                    outgoing.state = .Ringing
                    StatsConfig.postDialDelayEndTime = Utils.getCurrentTimeInMilliSeconds()
                    StatsConfig.ring_start_time = Utils.getCurrentTimeInMilliSeconds()
                    outgoing.callId = callId ?? "NA"
                    self.delegate?.onOutgoingCallRinging?(outgoing)
                    LogManager.shared.log(Constant.DEBUG_ONOUTGOING_CALL_RINGING_EVENT + "\(statusCode)", level: .debug)
                }else{
                    LogManager.shared.log("Outgoing Call: call state failed because curOutCall is nil", level: .error)
                }
            }
            
            //TODO: Check and uncomment below code
//            if (call_info.state == PJSIP_INV_STATE_CONNECTING) {
//                if((StatsConfig.postDialDelayEndTime == nil)) {
//                    StatsConfig.postDialDelayEndTime = Utils.getCurrentTimeInMilliSeconds()
//                }
//                StatsConfig.answer_time = Utils.getCurrentTimeInMilliSeconds()
//            }
            
            if otherReason == .CallAccepted{
                if let out = self.curOutCall{
                    // There is no connecting state in new implementation so adding those logic here
                    if((StatsConfig.postDialDelayEndTime == nil)) {
                        StatsConfig.postDialDelayEndTime = Utils.getCurrentTimeInMilliSeconds()
                    }
                    StatsConfig.answer_time = Utils.getCurrentTimeInMilliSeconds()
                    
//                    set_outgoing(call_id);
                    let outgoing:PlivoOutgoing = out
                    outgoing.state = .Ongoing
                    StatsConfig.call_confirmed_time = Utils.getCurrentTimeInMilliSeconds()
                    outgoing.callId = callId ?? "NA"
                    self.delegate?.onOutgoingCallAnswered?(outgoing)
                    sendCallAnsweredStats(call_id: callId ?? "NA", type: Constant.OUTGOING_ANSWERED_INFO)
                    LogManager.shared.log(Constant.DEBUG_ONOUTGOING_CALL_ANSWERED_EVENT + "\(statusCode)", level: .debug)
                }else{
                    LogManager.shared.log("Outgoing Call: call state failed because curOutCall is nil", level: .error)
                }
            }
        }
        
        
        
        // Call canceled or timeout from the other side before answering
        if terminateReason != nil{
            
            if  (480...489).contains(statusCode){
                if let out = self.curOutCall{
                    let outgoing:PlivoOutgoing = out
                    
                    StatsConfig.hangup_time = Utils.getCurrentTimeInMilliSeconds()
                    
                    outgoing.callId = callId ?? "NA"
                    
                    outgoing.state = .Terminated
                    
                    updateLastCallUUID()
                    
                    self.delegate?.onOutgoingCallRejected!(outgoing)
                    LogManager.shared.log(Constant.DEBUG_ONOUTGOING_CALL_REJECTED_EVENT + "\(statusCode)", level: .debug)
                }else{
                    LogManager.shared.log("Outgoing Call: call state failed because curOutCall is nil", level: .error)
                }
            }
            
            if  (404...408).contains(statusCode){
                if let out = self.curOutCall{
                    let outgoing:PlivoOutgoing = out
                    outgoing.state = .Terminated
                    outgoing.callId = callId ?? "NA"
                    self.delegate?.onOutgoingCallInvalid?(outgoing)
                    LogManager.shared.log(Constant.DEBUG_ONOUTGOING_CALL_INVALID_EVENT + "\(statusCode)", level: .debug)
                }else{
                    LogManager.shared.log("Outgoing Call: call state failed because curOutCall is nil", level: .error)
                }
            }
            
            if  statusCode == 503{
                if let out = self.curOutCall{
                    let outgoing:PlivoOutgoing = out
                    outgoing.state = .Terminated
                    outgoing.callId = callId ?? "NA"
                    self.delegate?.onOutgoingCallInvalid?(outgoing)
                    LogManager.shared.log(Constant.DEBUG_ONOUTGOING_CALL_INVALID_EVENT + "\(statusCode)", level: .debug)
                }else{
                    LogManager.shared.log("Outgoing Call: call state failed because curOutCall is nil", level: .error)
                }
            }
            
            if  statusCode == 200{
                if let out = self.curOutCall{
                    let outgoing:PlivoOutgoing = out
                    outgoing.state = .Terminated
                    outgoing.callId = callId ?? "NA"
                    
                    StatsConfig.hangup_time = Utils.getCurrentTimeInMilliSeconds()
                    
                    updateLastCallUUID()
                    
                    self.delegate?.onOutgoingCallHangup?(outgoing)
                    LogManager.shared.log(Constant.DEBUG_ONOUTGOING_CALL_HANGUP_EVENT + "\(statusCode)", level: .debug)
                }else{
                    LogManager.shared.log("Outgoing Call: call state failed because curOutCall is nil", level: .error)
                }
            }
            
        }
    }
    
    fileprivate func onCallState() {
        sipClient?.sipCallStateHandler { [weak self] (reason, statusCode) in
            
            guard let strongSelf = self else{
                LogManager.shared.log(" sip Callback sipCallStateHandler : self is nil", level: .critical)
                return
            }
            
            if let reason = reason{
                let otherReason = OtherReason.init(rawValue: reason)
                let terminateReason = TerminatedReason.init(rawValue: reason)
                
                if strongSelf.isIncomingCall{
                    strongSelf.incomingCallStates(otherReason, terminateReason, statusCode)
                }else{
                    strongSelf.outgoingCallStates(otherReason, statusCode, terminateReason)
                }
            }else{
                LogManager.shared.log("reSIProcate reason not found", level: .error)
            }
            
            LogManager.shared.log("reSIProcate reason : " + (reason ?? "reSIProcate reason NA") + " statusCode :\(statusCode)", level: .debug)
        }
    }
    
    fileprivate func sipClientEventHandler() {
        LogManager.shared.log("SIP CALLBACK - sipClientEventHandler", level: .info)
        sipClient?.registerCallHandler { [weak self] (callEvent, value) in
            
            guard let strongSelf = self else{
                LogManager.shared.log(" sip Callback in endpoint registerCallHandler : self is nil", level: .critical)
                return
            }
            
            strongSelf.isIncomingCall = false
            if (callEvent == IncomingCall) {
                strongSelf.isIncomingCall = true
                LogManager.shared.log(" sip Callback in endpoint registerCallHandler : IncomingCall ", level: .info)
            } else if (callEvent == TerminateCall) {
                LogManager.shared.log(" sip Callback in endpoint registerCallHandler : TerminateCall \(strongSelf.callId ?? "NA")", level: .info)
                
                if let terminateReason = value{
                    StatsConfig.hangup_party = terminateReason.getTerminateState.party
                    StatsConfig.hangup_reason = terminateReason.getTerminateState.reason
                }
                
                if let callId = strongSelf.callId{
                    strongSelf.sendCallSummaryStats(call_id: callId)
                }else{
                    LogManager.shared.log("not sending call summary on call termination | callid is nil | might be duplicate termination", level: .debug)
                }
                
            
                strongSelf.curIncomingCall?.state = .Terminated
                strongSelf.curOutCall?.state = .Terminated
                
                if let out = strongSelf.curOutCall{
                    strongSelf.delegate?.onOutgoingCallHangup?(out)
                }
                
                if let inCall = strongSelf.curIncomingCall{
                    strongSelf.delegate?.onIncomingCallHangup?(inCall)
                }
                
                strongSelf.webrtcAdapter.hangupCall()
                Thread.sleep(forTimeInterval: 0.05)
                strongSelf.curIncomingCall = nil
                strongSelf.curOutCall = nil
                
                strongSelf.statsTimer?.invalidate()
                strongSelf.statsTimer = nil
                
                strongSelf.ringTimer?.invalidate()
                strongSelf.ringTimer = nil
            
                if strongSelf.isApplicationinBackground == true{
                    LogManager.shared.log(" sip Callback in endpoint registerCallHandler : reset stack method requesting ", level: .info)
                    strongSelf.resetEndpoint()
                }
                
                strongSelf.callId = nil
//                strongSelf.backgroundResetEndpoint()
                
            } else if (callEvent == CallAccepted) {
                LogManager.shared.log(" sip Callback in endpoint registerCallHandler : CallAccepted ", level: .info)
            }
        }
        
        sipClient?.registerRegistrationHandler { [weak self] (registrationEvent, value) in
            
            guard let strongSelf = self else{
                LogManager.shared.log(" sip Callback in endpoint registerRegistrationHandler : self is nil", level: .critical)
                return
            }
            
            if (registrationEvent == Registered) {
                LogManager.shared.log(" sip Callback in endpoint registerRegistrationHandler : registered ", level: .info)
                
                strongSelf.isRegistered = true
                strongSelf.delegate?.onLogin?()
                LogManager.shared.log(Constant.DEBUG_ONLOGIN_EVENT, level: .debug)
            }else{
                strongSelf.isRegistered = false
                LogManager.shared.log(" sip Callback in endpoint registerRegistrationHandler : unregistered ", level: .info)
                strongSelf.delegate?.onLogout?()
                LogManager.shared.log(Constant.DEBUG_ONLOGOUT_EVENT, level: .debug)
            }
        }
        
        sipClient?.sipSDPHandler { [weak self] (sdp) in
            
            guard let strongSelf = self else{
                LogManager.shared.log(" sip Callback in endpoint sipSDPHandler : self is nil", level: .critical)
                return
            }
            
            if let sdpString = sdp , sdpString != ""{
                LogManager.shared.log(" sip Callback in endpoint sipSDPHandler \(sdp ?? "NA")", level: .info)
                //TODO: Change below logic, just testing it now
                if strongSelf.isIncomingCall{
                    strongSelf.webrtcAdapter.setRemote(offerSDP: sdpString)
                    strongSelf.on_incoming_call(callInfo: strongSelf.callData)
                }else{
                    strongSelf.curOutCall?.webrtcAdapter?.setRemote(answerSDP: sdpString)
                }
                
            }else{
                LogManager.shared.log(" in endpoint Remote answer SDP in ougoing call is nil ", level: .error)
            }
        }
        
        sipClient?.registerErrorHandler { [weak self] (errorType, value) in
            
            guard let strongSelf = self else{
                LogManager.shared.log(" sip Callback in endpoint registerErrorHandler : self is nil", level: .critical)
                return
            }
           
            if let error = Utils.error(withMessage: "Error while registering status code: \(Int(value ?? "0") ?? 0)", code: Int(value ?? "0") ?? 0){
                LogManager.shared.log(" \(strongSelf.delegate == nil) sip Callback in endpoint registerErrorHandler \(errorType) \(value ?? "NA")", level: .info)
                strongSelf.delegate?.onLoginFailed?()
                strongSelf.delegate?.onLoginFailedWithError?(error)
                LogManager.shared.log(Constant.DEBUG_LOGIN_FAILED_EVENT, level: .debug)
            }
        }
        
        //TODO: Check for weak self in clousers
        sipClient?.sipCallInfoHandler { [weak self] (callInfo) in
            
            LogManager.shared.log(" sip Callback in endpoint sipCallInfoHandler \(String(describing: callInfo)) callid :\(String(describing: callInfo?.callId))", level: .debug)
            
            guard let strongSelf = self else{
                LogManager.shared.log(" sip Callback in endpoint sipCallInfoHandler : self is nil", level: .critical)
                return
            }
            
            strongSelf.getXCallUUID()
            strongSelf.callId = callInfo?.callId
            strongSelf.callData = callInfo
        }
        
        sipClient?.registerLogHandler { (logValue) in
            if let log = logValue{
                LogManager.shared.log(log, level: .debug)
            }
        }
        
        //Note:Handler when invite state has changed.
        self.onCallState()
    }
    
    private func on_incoming_call(callInfo:String?){
        LogManager.shared.log(" sip Callback in endpoint data on_incoming_call \(callInfo ?? "NA") and callid \(callInfo?.callId ?? "NA")", level: .info)
        
        Utils.setInviteFlag(true)
        
        
        let incomingCall = plivo_incoming_object_with_extra_headers(call: curIncomingCall, callInfo: callInfo)
        self.curIncomingCall = incomingCall
        
        LogManager.shared.log("PlivoIncomingObject \(curIncomingCall.debugDescription)")
        
        incomingCall.state = .Ringing
        
        //TODO: Reject the call when we already have active ongoing call
        
        // Adding call_id to incomingcallobj if not present. This is used so we don't
        // send multiple notifications for the same SIP call UUID
        
        LogManager.shared.log(" extra headers \(callInfo?.callInfoDictionaryString)", level: .info)
        
        self.webrtcAdapter.incomingDelegate = self

//        self.webrtcAdapter.createAnswer()
        
        LogManager.shared.log("reporting onIncomingCall isInvalidInvite \(isInvalidInvite) isSipToSipInvite \(isSipToSipInvite)", level: .info)
        
        self.sipClient?.sendRinging()
        
        if (isInvalidInvite == false && isSipToSipInvite == true){
            Utils.setAnswerFlag(false)
            Utils.setRejectFlag(false)
            LogManager.shared.log("reporting onIncomingCall", level: .info)
            self.delegate?.onIncomingCall?(incomingCall)
            LogManager.shared.log(Constant.DEBUG_ONINCOMING_CALL_EVENT, level: .debug)
        }
        
        if self.isInvalidInvite{
            self.isInvalidInvite = false
            LogManager.shared.log("Reject incoming call in on_incoming_call isInvalidInvite == true", level: .info)
            self.curIncomingCall?.reject()
            LogManager.shared.log("Returing flow from here because it's invalid invite", level: .info)
            return
        }
        
        if Utils.getAnswerFlag() && Utils.getRejectFlag(){
            LogManager.shared.log("Reject incoming call in on_incoming_call Utils.getAnswerFlag() == true && Utils.getRejectFlag() == true", level: .info)
            self.curIncomingCall?.reject()
        }else if Utils.getAnswerFlag(){
            self.curIncomingCall?.answer()
        }else if Utils.getRejectFlag(){
            LogManager.shared.log("Reject incoming call in on_incoming_call else", level: .info)
            self.curIncomingCall?.reject()
        }
        
        self.isSipToSipInvite = true
    }
    
    private func plivo_incoming_object_with_extra_headers(call:PlivoIncoming?, callInfo:String?)->PlivoIncoming{
        // Fetching call info, call_info would contain the
        // remote and local contact information, which would
        // be used to initialize the PlivoIncoming object.
        var incomingCall = call
        
        if call == nil {
            LogManager.shared.log("plivo_incoming_object_with_extra_headers() recreating object", level: .debug)
            if self.sipClient != nil {
                incomingCall = PlivoIncoming(sipAdapter: sipClient!, webrtcAdapter: self.webrtcAdapter)
            }else{
                LogManager.shared.log("SipClient object is nil", level: .error)
            }
        }
        
        if let info = callInfo{
            //        incomingCall?.accId =
            incomingCall?.callId = info.callId
            incomingCall?.fromContact = info.from ?? ""//TODO:Check for contatc and uri diff
            incomingCall?.toContact = info.to ?? ""
            incomingCall?.extraHeaders = info.extraHeaders
            incomingCall?.fromUser = info.fromUri ?? ""
        }
        
        LogManager.shared.log("incoming call: call info callerId \(callInfo?.fromUri)", level: .debug)
        
        return incomingCall!
    }
    
    func createIncomingCallObject(info:String)->PlivoIncoming?{
       return nil
    }
    
//    @objc func backgroundResetEndpoint(){
//        LogManager.shared.log("backgroundResetEndpoint endpoint", level: .debug)
//        let _ = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] timer in
//            LogManager.shared.log(" backgroundResetEndpoint checking is app is in background. then reset ", level: .info)
//            if let isBackground = self?.isApplicationinBackground, isBackground == true{
//                LogManager.shared.log(" backgroundResetEndpoint in background ", level: .info)
//                self?.resetEndpoint()
//            }
//        }
//    }
    
    @objc public func resetEndpoint(){
        LogManager.shared.log("reseting endpoint", level: .debug)
        self.isIncomingCall = false
        self.isRegistered = false
        self.sipClient?.resetStack()
    }
}



//MARK: - WebrtcAdapterIncomingDelegate
extension PlivoEndpoint:WebrtcAdapterIncomingDelegate{
    
    func didConnectCall() {
        LogManager.shared.log("PlivoEndpoint WebrtcAdapterIncomingDelegate didConnectCall", level: .debug)
        curIncomingCall?.state = .Ongoing
        curOutCall?.state = .Ongoing
    }
   
    func onIceCandidate(sdp: String, sdpMid: String) {
        self.sipClient?.onIceCandidate(sdp, andMid: sdpMid)
    }
    
    func onIceGatheringFinish() {
        self.sipClient?.onIceGatheringFinished()
    }
    
    func sendAnswer(localSDP: String) {
        if curIncomingCall?.isCallAnswered == true {
            LogManager.shared.log("User already accepted call making answer when sdp is ready", level: .debug)
            self.sipClient?.answer(localSDP)
        }else{
            LogManager.shared.log(" webrtcAdapter callback \(curIncomingCall?.isCallAnswered) ", level: .info)
            LogManager.shared.log(" webrtcAdapter?.sendAnswer \(localSDP) sipUri : \(curIncomingCall?.toContact ?? "NIL") ", level: .info)
            curIncomingCall?.localSdp = localSDP
        }
    }
    
    
}






//MARK: - Delegate defined in PlivoIncoming class
extension PlivoEndpoint:PlivoIncomingDelegate{
    
    func triggerOnIncomingCallInvalidNotification() {
        if let currentIncoming = self.curIncomingCall{
            self.delegate?.onIncomingCallInvalid?(currentIncoming)
            LogManager.shared.log(Constant.DEBUG_ONINCOMING_CALL_INVALID_EVENT, level: .debug)
        }
    }
    
}





//MARK: - Feedback Interface
extension PlivoEndpoint{
    /// Description
    /// - Parameters:
    ///   - callUUID: callUUID description
    ///   - startRating: startRating description
    ///   - issues: issues description
    ///   - notes: notes description
    ///   - sendConsoleLog: sendConsoleLog description
    @objc public func submitCallQualityFeedback(_ callUUID: String?, _ startRating: Int, _ issues: [AnyObject], _ notes: String, _ sendConsoleLog: Bool) {
        
        guard let feedbackManager = self.feedbackManager else {
            LogManager.shared.log("Feedback manager object not found | Returing from code block", level: .error)
            return
        }
        
        var issueStringList = issues.map({$0 as? String ?? "NAC"})
        
        let status = feedbackManager.validateInputs(callUUID, startRating, issueStringList, notes, sendConsoleLog)
        
        if (status["false"] != nil){
            self.delegate?.onFeedbackValidationError?((status["false"] as? String) ?? "Unknown")
            LogManager.shared.log(Constant.DEBUG_FEEDBACKALIDATION_ERROR_EVENT, level: .debug)
        }
        
        if (status["issues"] != nil){
            issueStringList = status["issues"] as! [String]
        }
        
        let params = ["username": StatsConfig.username ?? "", "password" : StatsConfig.password ?? "", "calluuid" : callUUID ?? "NA", "domain" : Environment.sipDomain, "source" :Constant.SOURCE]
        
        if JSONSerialization.isValidJSONObject(params) {
            
            HTTPClient.shared.postRequest(url: Constant.S3BUCKET_API_URL, params: params) { response in
                switch response{
                case let .success(value):
                    
                    var issueToLower: [String] = []
                    for str in issueStringList {
                        issueToLower.append(str.lowercased())
                    }
                    let orderedSet = NSOrderedSet(array: issueToLower)
                    
                    let issueWithoutDuplicates = orderedSet.array.compactMap({$0 as? String})
                    var feedback = issueWithoutDuplicates.map(\.description).joined(separator: " ")
                    feedback = "\("[") \(feedback) \("] ") \(notes)"
                    
                    var putData = [
                        "overall" : "\(startRating)",
                        "comment" : feedback
                    ]
                    
                    if sendConsoleLog {
                        putData["log"] = logs
                    }
                    
                    if JSONSerialization.isValidJSONObject(putData) {
                        if let json = value as? [String: Any], let s3UrlString = json["data"] as? String{
                            LogManager.shared.log("S3 URL \(s3UrlString)", level: .debug)
                            
                            HTTPClient.shared.putRequest(urlString: s3UrlString, params: putData) { (response) in
                                switch response{
                                case .success(_):
                                    self.delegate?.onFeedbackSuccess?(200)
                                    LogManager.shared.log(Constant.DEBUG_FEEDBACKALIDATION_SUCCESS_EVENT, level: .debug)
                                    break
                                case let .failure(error):
                                    self.delegate?.onFeedbackFailure?(error)
                                    LogManager.shared.log(Constant.DEBUG_FEEDBACKALIDATION_FAUILER_EVENT, level: .debug)
                                    break
                                }
                            }
                        }
                    }
                    LogManager.shared.log("S3 URL 2", level: .debug)
                    if let json = value as? [String: Any], let s3UrlString = json["data"]{
                        LogManager.shared.log("S3 URL \(s3UrlString)", level: .debug)
                    }else{
                        LogManager.shared.log("Response from validate API is null", level: .error)
                        if let customError = Utils.error(withMessage: "Response from validate API is null", code: 409){
                            self.delegate?.onFeedbackFailure?(customError)
                            LogManager.shared.log(Constant.DEBUG_FEEDBACKALIDATION_FAUILER_EVENT, level: .debug)
                        }
                    }
                    break
                case let .failure(error):
                    LogManager.shared.log("Error while calling S3 bucket API \(error)", level: .error)
                    self.delegate?.onFeedbackFailure?(error)
                    LogManager.shared.log(Constant.DEBUG_FEEDBACKALIDATION_FAUILER_EVENT, level: .debug)
                    break
                }
            }
        }else{
            LogManager.shared.log("Error : Not able to parse request payload", level: .error)
        }
        
    }
    
}




//MARK: - Call stats Interface
extension PlivoEndpoint: RTPStatsDelegate{
    
    func emitMediaMetrics(_ group: String, _ level: String, _ type: String, _ value: Double, _ active: Bool, _ desc: String, _ stream: String) {
        let msgTemplate = [
            "group": group,
            "level": level,
            "type": type,
            "value": NSNumber(value: value),
            "active": NSNumber(value: active),
            "desc": desc,
            "stream": stream
        ] as [String : Any]
        self.delegate?.mediaMetrics?(msgTemplate)
        LogManager.shared.log(Constant.DEBUG_MEDIA_METRICES_EVENT, level: .debug)
    }
    
    private func updateLastCallUUID(){
        StatsConfig.last_call_uuid = StatsConfig.x_call_uuid
    }
    
    func getXCallUUID(){
        if (callData?.isExtraHeadersAvailable ?? false){
            StatsConfig.x_call_uuid = callData?.extraHeaders["X-CallUUID"] as? String
        }
    }
    
    func sendCallSummaryStats(call_id: String){
        if let isEnableTracking = initOptions["enableTracking"] as? Bool, isEnableTracking == false  && (StatsConfig.stats_key == nil) {
            LogManager.shared.log("sendCallSummaryStats() | Not sending bcz either enableTracking == false || Stats Key is nil returing from here", level:.error)
            return
        }
        
        LogManager.shared.log("sendCallSummaryStats() Processing with callid : \(call_id)", level:.debug)
        
        StatsConfig.call_uuid = call_id;
        StatsConfig.msg = Constant.CALL_SUMMARY_MSG;
        
        guard let rtpStat = rtpStats else { LogManager.shared.log("sendCallSummaryStats()  RTPStats object is nil", level:.error); return }
        
        var statsDict = rtpStat.getInitialStats(isCallAnswered: true)
        let signalDict =  rtpStat.getSignallingStats()
        statsDict["signalling"] = signalDict
        statsDict["setupOptions"] = initOptions;
        self.feedbackManager?.sendStats(statsDict: &statsDict, type: Constant.CALL_SUMMARY_MSG)
        
        if(statsTimer != nil) {
            statsTimer?.invalidate()
        }
        
        if(audioTimer != nil) {
            audioTimer?.invalidate()
        }
    }
    
    func sendCallAnsweredStats(call_id: String, type: String) {
        if StatsConfig.stats_key == nil {
            rtpStats?.getCallStatsKey()
        }
        
        if let isEnableTracking = initOptions["enableTracking"] as? Bool, isEnableTracking == false  && (StatsConfig.stats_key == nil) {
            LogManager.shared.log("sendCallAnsweredStats() | Not sending bcz either enableTracking == false || Stats Key is nil returing from here", level:.error)
            return
        }
        
        LogManager.shared.log("sendCallAnsweredStats() with callid : \(call_id) and callInfo : \(type) Call Type : \(self.isIncomingCall ? "INBOUND": "OUTBOUND")", level:.info)
        
        StatsConfig.call_uuid = call_id
        StatsConfig.msg = Constant.CALL_ANSWERED_MSG
        StatsConfig.info = type
        
        guard let rtpStat = rtpStats else { LogManager.shared.log("sendCallAnsweredStats()  RTPStats object is nil | return", level:.error); return }
        
        var statsDict = rtpStat.getInitialStats(isCallAnswered: true)
        statsDict["info"] = StatsConfig.info
        statsDict["setupOptions"] = initOptions
        
        feedbackManager?.sendStats(statsDict: &statsDict, type: Constant.CALL_ANSWERED_MSG)
        
        if StatsConfig.rtp_enabled == true {
            LogManager.shared.log("RTP is enabled for this user from call insights", level: .debug)
            if let enableTracking = initOptions["enableTracking"] as? Bool, enableTracking{
                LogManager.shared.log("RTP is enabled for this user from options", level: .debug)
                if statsTimer == nil && !(statsTimer?.isValid ?? false){
                    statsTimer = Timer(timeInterval: Constant.STATS_COLLECT_INTERVAL, target: self, selector: #selector(sendCallIntervalStats(_:)), userInfo: call_id, repeats: true)
                    RunLoop.main.add(statsTimer!, forMode: .default)
                }
            }else{
                LogManager.shared.log("RTP is not enabled for this user from options", level: .debug)
            }
        } else {
            LogManager.shared.log("RTP is not enabled for this user from call insights", level: .debug)
        }
    }
    
    @objc func sendCallIntervalStats(_ timer: Timer) {
        LogManager.shared.log("Sending call stats after every \(Constant.STATS_COLLECT_INTERVAL) seconds", level: .info)
        
        StatsConfig.msg = Constant.CALL_STATS_MSG
        
        guard let rtpStat = rtpStats else { LogManager.shared.log("sendCallIntervalStats()  RTPStats object is nil | return", level:.error); return }
        
        var statsDict = rtpStat.getInitialStats(isCallAnswered: false)
        
        self.webrtcAdapter.getStats { (statsString, dumpString) in
            self.delegate?.rtpStats(dumpString)
            
            if statsString.isEmpty{
                LogManager.shared.log("sendCallIntervalStats() call media state, stream stats could not be fetched", level: .alert)
            }else{
                if let stats = statsString.convertToDictionary(){
                    statsDict["local"] = rtpStat.getLocalStats(stats)
                    statsDict["remote"] = rtpStat.getRemoteStats(stats)
                }else{
                    LogManager.shared.log("sendCallIntervalStats() RTCStats dictionary is not valid", level: .alert)
                }
                
                if let dict = statsString.convertToDictionary(), let localCodec = dict["codec"] as? String{
                    statsDict["codec"] = localCodec
                }
                
                statsDict["networkDownlinkSpeed"] = NSNumber(value: -1)
                statsDict["networkEffectiveType"] = "unknown"
                statsDict["networkType"] = Utils.getConnectionType()
                
                self.feedbackManager?.sendStats(statsDict: &statsDict, type: Constant.CALL_STATS_MSG)
            }
        }
    }
    
}
