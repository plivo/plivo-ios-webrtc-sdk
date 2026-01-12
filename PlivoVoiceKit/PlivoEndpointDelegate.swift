//
//  PlivoEndpointDelegate.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 02/02/21.
//

import Foundation
import AVFAudio

@objc public protocol PlivoEndpointDelegate{
    /// This delegate gets called when registration to an endpoint is successful.
    @objc optional func onLogin()
    
    /// This delegate gets called when registration to an endpoint fails.
    @available(*, deprecated, message: "This method will be deprecated, please use 'onLoginFailedWithError:")
    @objc optional func onLoginFailed()
    
    /// This delegate gets called when registration to an endpoint fails.
    /// - Parameter error: reason of failure
    @objc optional func onLoginFailedWithError(_ error: Error)
    
    /// This delegate gets called when the permission is not allowed for incoming/outgoing calls in jwt token.
    /// - Parameter error: reason of failure
    @objc optional func onPermissionDenied(_ error: Error)
    
    /// This delegate gets called when the input/output audio device is changed
    /// - Parameter error: reason of failure
    @objc optional func audioDeviceChange(deviceChange: String, deviceInfo: AVAudioSessionRouteDescription)
    
    /// This delegate gets called when endpoint logged out.
    @objc optional func onLogout()
    
    /// On an incoming call to a registered endpoint, this delegate receives a PlivoIncoming object.
    /// - Parameter incoming: PlivoIncoming object.
    @objc optional func onIncomingCall(_ incoming: PlivoIncoming)
    
    /// On an incoming call connection  setup for media transfer, this delegate receives a PlivoIncoming object.
    /// - Parameter incoming: PlivoIncoming object.
    @objc optional func onIncomingCallConnected(_ incoming: PlivoIncoming)
    
    /// On an incoming call, if the call is answered by the caller, this delegate would be triggered with the PlivoIncoming object.
    /// - Parameter incoming: PlivoIncoming object
    @objc optional func onIncomingCallAnswered(_ incoming: PlivoIncoming)
    
    /// On an incoming call, if the call is disconnected by the caller, this delegate would be triggered with the PlivoIncoming object.
    /// - Parameter incoming: PlivoIncoming object
    @objc optional func onIncomingCallRejected(_ incoming: PlivoIncoming)
    
    /// On an incoming call, if the call gets timed out, this delegate would be triggered.
    /// - Parameter incoming: PlivoIncoming object
    @objc optional func onIncomingCallInvalid(_ incoming: PlivoIncoming)
    
    /// On an incoming call, if the call is disconnected by the caller after being answered, this delegate would be triggered with the PlivoIncoming object.
    /// - Parameter incoming: PlivoIncoming object
    @objc optional func onIncomingCallHangup(_ incoming: PlivoIncoming)
    
    /// On an active endpoint, this delegate would be called with the digit received on the call.
    /// - Parameter digit: DTMF digit in string
    @objc optional func onIncomingDigit(_ digit: String)
    
    /// When an outgoing call is started, this delegate would be called with the PlivoOutgoing object.
    /// - Parameter call: PlivoOutgoing object
    @objc optional func onCalling(_ call: PlivoOutgoing)
    
    /// When an outgoing call is answered, this delegate would be called with the PlivoOutgoing object.
    /// - Parameter call: PlivoOutgoing object
    @objc optional func onOutgoingCallAnswered(_ call: PlivoOutgoing)
    
    /// When an outgoing call is ringing, this delegate would be called with the PlivoOutgoing object.
    /// - Parameter call: PlivoOutgoing object
    @objc optional func onOutgoingCallRinging(_ call: PlivoOutgoing)
    
    /// When an outgoing call is rejected by the called number, this delegate would be called with the PlivoOutgoing object.
    /// - Parameter call: PlivoOutgoing object
    @objc optional func onOutgoingCallRejected(_ call: PlivoOutgoing)
    
    /// When an outgoing call is made to an invalid number, this delagate would be called with the PlivoOutgoing object.
    /// - Parameter call: PlivoOutgoing object
    @objc optional func onOutgoingCallInvalid(_ call: PlivoOutgoing)
    
    /// When an outgoing call is disconnected by the called number after the call has been answered.
    /// - Parameter call: PlivoOutgoing object
    @objc optional func onOutgoingCallHangup(_ call: PlivoOutgoing)
    
    /// When the user feedback is successfully submitted to the server.
    /// - Parameter statusCode: HTTP status code
    @objc optional func onFeedbackSuccess(_ statusCode: Int)
    
    /// When the user feedback request is failed due to some reason.
    /// - Parameter error: reason of failure
    @objc optional func onFeedbackFailure(_ error: Error)
    
    /// When the user feedback request is failed due to some reason, And returns an error reason.
    /// - Parameter validationErrorMessage: reason of failure
    @objc optional func onFeedbackValidationError(_ validationErrorMessage: String)
    
    /// When the media metrics are available.
    /// - Parameter mediaInfo: media metrics data in dictionary.
    @objc optional func mediaMetrics(_ mediaInfo: [AnyHashable : Any])
    
    @objc optional func logs(_ value: String, level:String)
    @objc optional func rtpStats(_ value: String)
    @objc optional func speakingOnMute()
    

}
