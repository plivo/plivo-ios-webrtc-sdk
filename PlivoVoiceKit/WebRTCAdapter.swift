//
//  WebRTCAdapter.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 04/02/21.
//

import Foundation

protocol WebrtcAdapterOutgoingDelegate {
    func sendOffer(localSDP:String)
    func sendOffer(localSDP:String, headers: [AnyHashable : Any])
    func onIceCandidate(sdp:String, sdpMid: String)
    func onIceGatheringFinish()
//    func didConnectCall()
}

protocol WebrtcAdapterIncomingDelegate {
    func onIceCandidate(sdp:String, sdpMid: String)
    func onIceGatheringFinish()
    func didConnectCall()
}

class WebrtcAdapter: NSObject {
    
    let webRTCClient = WebRTCClient()
    var outgoingDelegate:WebrtcAdapterOutgoingDelegate?
    var incomingDelegate:WebrtcAdapterIncomingDelegate?
    
    private var isIncoming = false
    
    func configureAudioSession(){
        webRTCClient.configureAudioSession()
    }
    
    override init() {
        super.init()
        self.webRTCClient.delegate = self
        LogManager.shared.log("init WebrtcAdapter", level: .info)
    }
    
    deinit {
        LogManager.shared.log("deinit WebrtcAdapter", level: .info)
    }
    
    //Outgoing Call
    func sendOffer(isIceRestartRequired:Bool){
        self.isIncoming = false
        LogManager.shared.log("Send Offer in WebrtcAdapter without headers", level: .info)
        
        webRTCClient.createOffer(isIceRestartRequired: isIceRestartRequired, onSuccess: { (offerSDP) in
            if isIceRestartRequired == false{
                self.outgoingDelegate?.sendOffer(localSDP: offerSDP)
            }
        })
    }
    
    func sendOffer(isIceRestartRequired:Bool,headers:[AnyHashable : Any]){
        self.isIncoming = false
        LogManager.shared.log("Send Offer in WebrtcAdapter with headers", level: .info)
        
        webRTCClient.createOffer(isIceRestartRequired: isIceRestartRequired, onSuccess: { (offerSDP) in
            if isIceRestartRequired == false{
//                LogManager.shared.infoLogs(log: "Outgoing | SDP Offer created: \(offerSDP)")
                LogManager.shared.infoLogs(log: "Outgoing | SDP Offer created")
                self.outgoingDelegate?.sendOffer(localSDP: offerSDP, headers: headers)
            }
        })
    }
    
    func mute() {
        webRTCClient.mute()
    }
    
    func unmute() {
        webRTCClient.unmute()
    }
    
    func hold(){
        webRTCClient.hold()
    }
    
    func unhold(){
        webRTCClient.unhold()
    }
    
    func setRemote(answerSDP:String){
        webRTCClient.setRemote(answerSDP: answerSDP)
    }
    
    func setRemote(offerSDP:String){
        self.isIncoming = true
        webRTCClient.setRemote(offerSDP: offerSDP)
    }
    
    func createAnswer(onCreateAnswer: @escaping (String) -> Void){
        LogManager.shared.log("WebRTCClient | trying to createAnswer()", level: .debug)
        webRTCClient.createAnswer(onCreateAnswer: onCreateAnswer)
    }
    
    func sendDigits(digits:String){
        webRTCClient.dtmfTonePlayer(digits)
    }
    
    func hangupCall(){
        webRTCClient.webrtcSessionHangup()
    }
    
    func getStats(stats: @escaping(_ rtpStats:String, _ rtpDump:String) -> Void){
        webRTCClient.getRTPStats { rtpStats, rtpDump in
            stats(rtpStats,rtpDump)
        }
    }
    
    func startAudio(){
        webRTCClient.startAudio()
    }
    
    func stopAudio(){
        webRTCClient.stopAudio()
    }
    
}



extension WebrtcAdapter:WebRTCClientDelegate{
    
    func didGenerateCandidate(sdp: String, andMid: String) {
        if self.isIncoming{
            self.incomingDelegate?.onIceCandidate(sdp: sdp, sdpMid: andMid)
        }else{
            self.outgoingDelegate?.onIceCandidate(sdp: sdp, sdpMid: andMid)
        }
    }
    
    
    func didIceGatheringChangedWebRTC(onIceGatheringComplete: Bool) {
        if onIceGatheringComplete{
            if self.isIncoming{
                self.incomingDelegate?.onIceGatheringFinish()
            }else{
                self.outgoingDelegate?.onIceGatheringFinish()
            }
        }
    }
    
    func didConnectWebRTC() {
        Utils.IS_CALL_RUNNING = true
        self.incomingDelegate?.didConnectCall()
    }
    
    func didDisconnectWebRTC() {
        Utils.IS_CALL_RUNNING = false
    }
    
}
