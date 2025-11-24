//
//  WebRTCConstants.swift
//  VoipDemo
//
//  Created by Krishna Thakur on 20/01/21.
//  Copyright © 2021 Plivo. All rights reserved.
//

import Foundation
import WebRTC

class WebRTCConstants {
    
    static var configuration : RTCConfiguration {
        let config = RTCConfiguration()
        config.iceServers = WebRTCConstants.iceServers
//        config.iceConnectionReceivingTimeout = 1
//        config.maxIPv6Networks = INT_MAX
//        config.candidateNetworkPolicy = .all
//        config.disableIPV6OnWiFi = true
//        config.disableIPV6 = true
//        config.sdpSemantics = .planB
        config.continualGatheringPolicy = .gatherContinually
//        config.bundlePolicy = .maxCompat
//        config.keyType = .ECDSA
        config.rtcpMuxPolicy = .negotiate
//        config.iceTransportPolicy = .all
//        config.tcpCandidatePolicy = .enabled
        return config
    }
    
    static let rtcMediaConstraints = RTCMediaConstraints(mandatoryConstraints: WebRTCConstants.mediaConstrains, optionalConstraints: WebRTCConstants.optionalConstrains)
    static let iceRestartRtcMediaConstraints = RTCMediaConstraints(mandatoryConstraints: WebRTCConstants.iceRestartmediaConstrains, optionalConstraints: WebRTCConstants.optionalConstrains)
    
    private static let mediaConstrains = [
        kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
        kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueFalse
    ]
    
    private static let iceRestartmediaConstrains = [
        kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
        kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueFalse,
        kRTCMediaConstraintsIceRestart:kRTCMediaConstraintsValueTrue
    ]
    
    private static let optionalConstrains = [
        "DtlsSrtpKeyAgreement":"true",
//        "RtpDataChannels":"true",
//        "internalSctpDataChannels":"true",
        "googIPv6":"true"
    ]
    
    private static let iceServers = [RTCIceServer(urlStrings:  ["stun:stun.l.google.com:19302"])]
}
