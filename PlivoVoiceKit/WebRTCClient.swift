//
//  WebRTCClient.swift
//  VoipDemo
//
//  Created by Krishna Thakur on 21/12/20.
//  Copyright © 2020 Harman. All rights reserved.
//
import Foundation
import AVFoundation
import WebRTC

protocol WebRTCClientDelegate:class {
    func didGenerateCandidate(sdp:String, andMid: String)
    func didConnectWebRTC()
    func didDisconnectWebRTC()
    func didIceGatheringChangedWebRTC(onIceGatheringComplete:Bool)
}

class WebRTCClient: NSObject {
    private let audioSession = RTCAudioSession.sharedInstance()
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack!
    private var remoteStream: RTCMediaStream?
    private var rTCMediaStreamTrack: RTCMediaStreamTrack?
    public private(set) var isConnected: Bool = false
    weak var delegate: WebRTCClientDelegate?
    private var statsTimer: Timer?
    var callMuted = false
    var callHolded = false
    var maxAverageBitrate = Constant.MAX_AVERAGE_BITRATE
    
    
    private let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(),
                                        decoderFactory: RTCDefaultVideoDecoderFactory())
    }()

    override init() {
        super.init()
        LogManager.shared.log("init WebRTCClient | RTCPeerConnection", level: .debug)
        self.setupPeerConnection()
    }

    func setupPeerConnection(){
        LogManager.shared.log("WebRTCClient | setupPeerConnection ", level: .debug)
        peerConnection = factory.peerConnection(with: WebRTCConstants.configuration, constraints: WebRTCConstants.rtcMediaConstraints, delegate: nil)
        
        self.setupLocalTracks()
        self.configureAudioSession()
        peerConnection?.delegate = self
    }
    
    private func disposePeerConnection(){
        LogManager.shared.log(" WebRTCClient | disposePeerConnection", level: .info)
        if self.peerConnection != nil{
            self.peerConnection!.close()
            self.peerConnection = nil
        }
    }
    
    deinit {
        RTCCleanupSSL()
        LogManager.shared.log("deinit WebRTCClient", level: .debug)
        resetTimer()
    }
    
}






// MARK: - Signaling Set Remote Offer/Answer
extension WebRTCClient{
    
    //Incomming Call
    func setRemote(offerSDP: String){
        if self.peerConnection == nil{
            LogManager.shared.log("WebRTCClient | peer Connection was closed recreating peerconnection", level: .debug)
            self.setupPeerConnection()
        }
        
        LogManager.shared.log("WebRTCClient | trying to setRemoteDescription() | offer SDP :\n \(offerSDP)", level: .debug)
        let remoteSDP = RTCSessionDescription(type: .offer, sdp: offerSDP)
        self.peerConnection?.setRemoteDescription(remoteSDP, completionHandler: { (err) in
            if let error = err {
                LogManager.shared.log("WebRTCClient | returing from here | failed to set REMOTE OFFER SDP | error : \(error.localizedDescription)", level: .error)
                return
            }
        })
    }

    //OutGoing Call
    func setRemote(answerSDP: String){
        let remoteSDP = RTCSessionDescription(type: .answer, sdp: answerSDP)
        LogManager.shared.log("WebRTCClient | trying to setRemoteDescription() | answer SDP :\n \(remoteSDP.sdp)", level: .debug)
        self.peerConnection?.setRemoteDescription(remoteSDP, completionHandler: { (err) in
            if let error = err {
                LogManager.shared.log("WebRTCClient | returing from here | failed to set REMOTE ANSWER SDP | error : \(error.localizedDescription)", level: .error)
                return
            }
        })
    }
    
}






// MARK: - Signaling Create Local Offer/Answer
extension WebRTCClient{
    
    //OutGoing Call
    func createOffer(isIceRestartRequired:Bool, onSuccess: @escaping (String) -> Void) {
        LogManager.shared.log("WebRTCClient | createOffer() with isIceRestartRequired : \(isIceRestartRequired)", level: .debug)
        
        if self.peerConnection == nil{
            LogManager.shared.log("WebRTCClient | peer Connection was closed recreating peerconnection", level: .debug)
            self.setupPeerConnection()
        }
        
        if self.peerConnection?.signalingState == RTCSignalingState.closed {
            LogManager.shared.log("WebRTCClient | returing from here| peerConnection signalingState is closed ", level: .error)
            return
        }
        
        self.peerConnection?.offer(for: isIceRestartRequired ? WebRTCConstants.iceRestartRtcMediaConstraints : WebRTCConstants.rtcMediaConstraints, completionHandler: { (sdp, err) in
            if let error = err {
                LogManager.shared.log(" returning from here | failed to create LOCAL ANSWER SDP \(error.localizedDescription)", level: .error)
                return
            }

            if let offerSDP = sdp {
                LogManager.shared.log("WebRTC:: make offer, created local sdp", level: .debug)
                self.peerConnection!.setLocalDescription(offerSDP, completionHandler: { (err) in
                    if let error = err {
                        LogManager.shared.log("WebRTC:: error with set local offer sdp \(error.localizedDescription)", level: .error)
                        return
                    }
                    var localSDP: String = offerSDP.sdp
                    localSDP = localSDP.replacingOccurrences(of: "useinbandfec=1", with: "useinbandfec=1;maxaveragebitrate=\(self.maxAverageBitrate)")

                    LogManager.shared.log("WebRTC:: succeed to set local offer SDP in outgoing call ", level: .debug)
                    onSuccess(localSDP)
                })
            }
        })
    }

    //Incomming Call
    func createAnswer(onCreateAnswer: @escaping (String) -> Void){
        LogManager.shared.log("WebRTCClient | createAnswer()", level: .debug)
        
        if self.peerConnection == nil{
            LogManager.shared.log("WebRTCClient | peer Connection was closed recreating peerconnection", level: .debug)
            self.setupPeerConnection()
        }
        
        if self.peerConnection?.signalingState == RTCSignalingState.closed {
            LogManager.shared.log("WebRTCClient | returing from here| peerConnection signalingState is closed ", level: .error)
            return
        }
        
        self.peerConnection?.answer(for: WebRTCConstants.rtcMediaConstraints, completionHandler: { (answerSessionDescription, err) in
            if let error = err {
                LogManager.shared.log("WebRTCClient |  returning from here | failed to create LOCAL ANSWER SDP error : \(error.localizedDescription)", level: .error)
                return
            }
            
            if let answerSDP = answerSessionDescription{
                    self.peerConnection!.setLocalDescription( answerSDP, completionHandler: { (err) in
                        if let error = err {
                            LogManager.shared.log("WebRTCClient | returing from here| failed to set local ansewr SDP error : \(error.localizedDescription)", level: .error)
                            return
                        }
                        
                        var localSDP: String = answerSDP.sdp
                        localSDP = localSDP.replacingOccurrences(of: "useinbandfec=1", with: "useinbandfec=1;maxaveragebitrate=\(self.maxAverageBitrate)")

                        LogManager.shared.log("WebRTCClient | succeed to set LOCAL ANSWER SDP", level: .debug)
                        onCreateAnswer(localSDP)
                    })
            }
            
        })
    }
    
}




//MARK: - Local Audio Setup
extension WebRTCClient{
   
    private func setupLocalTracks(){
        self.localAudioTrack = createAudioTrack()
        self.peerConnection?.add(localAudioTrack, streamIds: ["stream0"])
    }

    private func createAudioTrack() -> RTCAudioTrack {
        LogManager.shared.log("WebRTCClient | createAudioTrack()", level: .debug)
        let audioSource = self.factory.audioSource(with: WebRTCConstants.rtcMediaConstraints)
        let audioTrack = self.factory.audioTrack(with: audioSource, trackId: "audio0")
        return audioTrack
    }

    func startAudio() {
        audioSession.lockForConfiguration()
        do {
            try audioSession.setActive(true)
            audioSession.isAudioEnabled = true
            audioSession.unlockForConfiguration()
        } catch {
            audioSession.unlockForConfiguration()
            LogManager.shared.log("WebRTCClient | audioSession start error \(error.localizedDescription)", level: .error)
        }
    }
    
    func stopAudio() {
        audioSession.lockForConfiguration()
        do {
            try audioSession.setActive(false)
            audioSession.isAudioEnabled = false
            audioSession.unlockForConfiguration()
        } catch {
            LogManager.shared.log("WebRTCClient | audioSession stop error \(error.localizedDescription)", level: .error)
            audioSession.unlockForConfiguration()
        }
    }
    
    func configureAudioSession() {
        audioSession.useManualAudio = true
        audioSession.isAudioEnabled = false
        audioSession.lockForConfiguration()
       
        do {
            try
            audioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with:[ .mixWithOthers, .duckOthers])
            try audioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
//            try audioSession.overrideOutputAudioPort(.none)
            try audioSession.setActive(true)
            audioSession.unlockForConfiguration()
        } catch {
            LogManager.shared.log("WebRTCClient | audioSession properties weren't set because of an error.", level: .error)
            LogManager.shared.log("WebRTCClient | \(error.localizedDescription)", level: .error)
            audioSession.unlockForConfiguration()
        }
    }
    
    func mute(){
        self.callMuted = true
        localAudioTrack.isEnabled = false
        LogManager.shared.log("WebRTCClient | mute call | input voice disabled", level: .debug)
    }
    
    func unmute(){
        self.callMuted = false
        if callHolded{
            LogManager.shared.log("WebRTCClient | not enabling input voice | call is on hold", level: .debug)
        }else{
            localAudioTrack.isEnabled = true
        }
        LogManager.shared.log("WebRTCClient | unmute call input voice enabling", level: .debug)
    }
    
    func hold(){
        self.callHolded = true
        //We need to stop both party audio so first
        localAudioTrack.isEnabled = false
        //And then disable remote track
        if let audioTrack = self.remoteStream?.audioTracks.first{
            LogManager.shared.log("WebRTCClient | hold call | output voice disabled", level: .debug)
            audioTrack.isEnabled = false
        }
    }
    
    func unhold(){
        self.callHolded = false
        //We need to start both party audio so first
        if self.callMuted{
            LogManager.shared.log("Unholding the call in mute on", level: .alert)
        }else{
            localAudioTrack.isEnabled = true
        }
        //And then enable remote track
        if let audioTrack = self.remoteStream?.audioTracks.first{
            LogManager.shared.log("WebRTCClient | unhold output voice enabling", level: .debug)
            audioTrack.isEnabled = true
        }
    }
}




// MARK: - PeerConnection Delegeates
extension WebRTCClient: RTCPeerConnectionDelegate {

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        LogManager.shared.log("WebRTC:: signaling state changed: \(stateChanged.rawValue)", level: .debug)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        LogManager.shared.log(" RTCIceConnectionState didChange state changed: \(newState.rawValue)", level: .debug)
        switch newState {
        case .connected, .completed:
            self.delegate?.didConnectWebRTC()
            if !self.isConnected {
                self.isConnected = true
            }
        default:
            if self.isConnected{
                self.isConnected = false
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        LogManager.shared.log("WebRTCClient | RTCPeerConnectionDelegate | didAdd stream | stream id :\(stream.streamId) stream id :\(stream.streamId)", level: .debug)
        
        self.remoteStream = stream
        // Commenting out for audio quality. keeping it for future references
        // for track: RTCMediaStreamTrack in (stream.audioTracks as Array<RTCMediaStreamTrack>) {
        //     self.rTCMediaStreamTrack = track
        // }
        
        // if let audioTrack = stream.audioTracks.first{
        //     LogManager.shared.log("WebRTCClient | audio track found", level: .debug)
        //     audioTrack.source.volume = 8
        // }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        LogManager.shared.log("WebRTCClient | RTCPeerConnectionDelegate | didOpen dataChannel", level: .debug)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        LogManager.shared.log("WebRTCClient | RTCPeerConnectionDelegate | didGenerate candidate | new candidate sdp :\(candidate.sdp)", level: .debug)
        self.peerConnection?.add(candidate)
        self.delegate?.didGenerateCandidate(sdp: candidate.sdp, andMid: candidate.sdpMid ?? "NA")
//        self.delegate?.didGenerateCandidate(iceCandidate: candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        LogManager.shared.log("WebRTCClient | RTCPeerConnectionDelegate | didRemove stream", level: .debug)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        LogManager.shared.log("WebRTCClient | RTCPeerConnectionDelegate | didRemove candidates | removing candidates :\(candidates)", level: .debug)
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        LogManager.shared.log("WebRTCClient | RTCPeerConnectionDelegate | peerConnectionShouldNegotiate", level: .debug)
        if self.peerConnection?.signalingState != .stable {
            return
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        LogManager.shared.log("WebRTCClient | RTCPeerConnectionDelegate | didChange | RTCIceGatheringState | new state :\(newState.rawValue)", level: .debug)
        DispatchQueue.global(qos: .default).async {
            Thread.sleep(forTimeInterval: 1.0)
            LogManager.shared.log("changeGatheringState()", level: .debug)
            self.delegate?.didIceGatheringChangedWebRTC(onIceGatheringComplete: true)
        }
    }
    
}


// MARK: - PeerConnection DTMF
extension WebRTCClient{
    
    func dtmfTonePlayer(_ dtmfTone: String) {
        guard let pc = self.peerConnection else {
            LogManager.shared.log("dtmfTonePlayer() peerConnection is nil | returning from here", level: .error)
            return
        }
        
        var m_audioSender: RTCRtpSender? = nil
        for rtpSender in pc.senders {
            if rtpSender.track?.kind == "audio" {
                m_audioSender = rtpSender
            }
        }
        
        if let m_audioSender = m_audioSender {
            let queue = OperationQueue()
            queue.addOperation({
                let istoneplayed = m_audioSender.dtmfSender?.insertDtmf(
                    dtmfTone, duration: TimeInterval(0.1),
                    interToneGap: TimeInterval(0.5))
                print(istoneplayed ?? false ? "true" : "false")
            })
        }
    }
    
}

extension WebRTCClient{
    
    func resetTimer(){
        statsTimer?.invalidate()
        statsTimer = nil
        LogManager.shared.log("Stats timer decommisioned (stopped)", level: .debug)
    }
    
    func getRTPStats(stats: @escaping (_ rtpStats:String, _ rtpDump:String)-> Void){
        LogManager.shared.log("Get Stats called", level: .debug)
        if self.peerConnection?.signalingState == RTCSignalingState.closed {return}

        var statsDump = ""
        var statsDictionary = [String:Any]()
//
        let serialQueue = DispatchQueue(label: "serialQueue")
        let group = DispatchGroup()
//
        group.enter()
        
        self.peerConnection?.statistics(completionHandler: { (rtcReport) in

//            LogManager.shared.log("WEBRTC STATS DUMP \(rtcReport.statistics)", level: .debug)
            var codecKey = ""
            statsDump = rtcReport.statistics.debugDescription
            if let inboundrtp = rtcReport.statistics.filter({$0.value.type == "inbound-rtp"}).last?.value.values{
                statsDictionary["remote-rtp"] = inboundrtp
            }
            
            if let outbond = rtcReport.statistics.filter({$0.value.type == "outbound-rtp"}).last?.value.values{
                statsDictionary["local-rtp"] = outbond
            }
            
            if let remoteInboundrtp = rtcReport.statistics.filter({$0.value.type == "remote-inbound-rtp"}).last?.value.values{
                
                statsDictionary["remote-inbound-rtp"] = remoteInboundrtp
                
                codecKey = remoteInboundrtp["codecId"] as? String ?? ""
                
                if let codecValues = rtcReport.statistics.filter({$0.key == codecKey}).last?.value.values{
                    if let codecString = codecValues["mimeType"] as? String{
                        let strArray = codecString.split(separator: "/")
                        if let codec = strArray.last{
                            statsDictionary["codec"] = codec
                        }
                    }
                }
            }
            
            if let mediasource = rtcReport.statistics.filter({$0.value.type == "media-source"}).last?.value.values{
                statsDictionary["media-source"] = mediasource
            }
            
            group.leave()
            print("Done2")
        })
        
        group.notify(queue: serialQueue) {
            print("NOW READY")
            stats(Utils.convertDict(toJSON: statsDictionary), statsDump)
        }
       
    }
    // MARK: HangUp
    func webrtcSessionHangup(){
        LogManager.shared.log(" Webrtc call hangup", level: .info)
        self.isConnected = false
        self.callMuted = false
        self.callHolded = false
        self.delegate?.didDisconnectWebRTC()
        self.disposePeerConnection()
        self.resetTimer()
    }
}
