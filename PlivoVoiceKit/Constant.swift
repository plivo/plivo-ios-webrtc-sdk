//
//  Constant.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 03/02/21.
//

import Foundation

class Constant{
    static let STATS_API_URL = URL(string:"https://stats.plivo.com/v1/browser/validate/")
    static let STATSSOCKET_URL = URL(string: "wss://insights.plivo.com/ws")
    static let S3BUCKET_API_URL = URL(string:"https://stats.plivo.com/v1/browser/bucketurl/")
    static let S3BUCKET_API_URL_JWT = URL(string:"https://stats.plivo.com/v1/browser/bucketurl/jwt/")
    static let DOMAIN = "phone.plivo.com"
    static let NIMBUS_JWT_LOGS = "https://nimbus.plivo.com/collect/logs/jwt/"
    static let NIMBUS_LOGS = "https://nimbus.plivo.com/collect/logs/"

    static let OUTBOUND_PROXY = "client.plivo.com"
    static let FALLBACK_PROXY = "client-fb.plivo.com"
    static let STATS_API_URL_ACCESS_TOKEN = URL(string:"https://stats.plivo.com/v1/browser/validate/jwt/");

    static let SIP = "sip"
    static let SDK_NAME  = "PlivoWebRTCIOSSDK"
    static let STATS_SOURCE = "WebRTCIOSSDK"
    static let STATS_VERSION = "v1"
    static var PLIVO_ENDPOINT_VER : String {
        let version = "3.3.1"
        return "\(version)-beta"
    }
    static let CALL_ANSWERED_MSG = "CALL_ANSWERED"
    static let CALL_STATS_MSG = "CALL_STATS"
    static let CALL_SUMMARY_MSG = "CALL_SUMMARY"
    static let CALL_RINGING_MSG = "CALL_RINGING"
    static let TOGGLE_MUTE = "TOGGLE_MUTE"
    static let TOGGLE_HOLD = "TOGGLE_HOLD"
    static let AUDIO_DEVICE_TOGGLE = "AUDIO_DEVICES_TOGGLE"
    static let OUTGOING_ANSWERED_INFO = "Outgoing call answered"
    static let INCOMING_ANSWERED_INFO = "Incoming call answered"
    static let SOURCE = "ios"
    static let STATS_BUFFER_CAPACITY = 1
    static let STATS_COLLECT_INTERVAL = 5.0
    static let ANSWER_INVITE_CHECK_INTERVAL = 5.0
    static let RING_INVITE_CHECK_INTERVAL = 40.0
    static let MIN_AVERAGE_BITRATE = 8000
    static let SPEECH_TIMER = 3.0
    static let SPEECH_RECOGNITION_THRESHOLD = -80.0
    static let MAX_AVERAGE_BITRATE = 48000
    static var registrationTimeout = 3600*24*30
    static let DEFAULT_COMMENTS = [
        "AUDIO_LAG" : "audio_lag",
        "BROKEN_AUDIO": "broken_audio",
        "CALL_DROPPED": "call_dropped",
        "CALLERID_ISSUES": "callerid_issue",
        "DIGITS_NOT_CAPTURED": "digits_not_captured",
        "ECHO": "echo",
        "HIGH_CONNECT_TIME": "high_connect_time",
        "LOW_AUDIO_LEVEL": "low_audio_level",
        "ONE_WAY_AUDIO": "one_way_audio",
        "OTHERS": "others",
        "ROBOTIC_AUDIO": "robotic_audio"
    ] as [String : String]
    
    static let ALREADY_ONE_ACTIVE_CALL = "Please wait to finish already running call."
    static let ALREADY_ON_RINGING_STATE = "Please wait to finish already ringing call."
    static let ALREADY_ON_DAILING_STATE = "Please wait to finish already dailing call."
    static let FREQUENT_NETWORK_CHANGE_ERROR = "Frequent network change happned returing from here"
    static let RESET_SESSION_ON_NETWORK_CHANGE = "Network changed, resetting session"
    static let EMPTY_LOGIN_1 = "username or password should not be empty."
    static let EMPTY_LOGIN_2 = "username / password or devicetoken should not be empty."
    static let EMPTY_LOGIN_3 = "username / password / devicetoken or certificateId should not be empty."
    static let JWT_EMPTY_LOGIN_1 = "Access Token should not be empty."
    static let JWT_EMPTY_LOGIN_2 = "accessToken or devicetoken should not be empty."
    static let JWT_EMPTY_LOGIN_3 = "accessToken / devicetoken or certificateId should not be empty."
    static let FAILED_TO_CREATE_ERROR = "Failed to create error"
    static let ALREADY_REGISTERED = "User already registered. Invalidating this request"
    static let USER_NOT_REGISTERED = "User not registered yet. Login to register user"
    static let MOBILE_INTERNET = "On cellular network"
    static let WIFI_INTERNET = "On Wifi network"
    static let NO_INTERNET = "No internet"
    static let INVALID_SIP_USERNAME = "Login error : invalid SIP username"
    static let PROCESSING_PUSH_INFO = "relayVoipPushNotification(). processing push payload to modify sip registration : "
    static let NIL_SIPOBJECT = "ERROR SipClient object is nil"
    static let INVALID_SIP_SESSION = "Invalid SIP session. Please register again before making call!"
    static let INVITE_TIMER_STARTED = "Invite timer started in ringing state"
    
    static let INVALID_SIP_URI = "Error initiating SIP call, Invalid URI"
    static let EMPTY_URI = "Empty Callee URI"
    static let ERROR_IN_CALL_WITH_HEADERS_INVALID_SIP_URI = "Error in call with Headers: Invalid URI"
    static let ERROR_IN_CALL_WITH_HEADERS_NO_HEADER = "Error in call with Headers: No Headers found"
    static let ERROR_IN_UNHOLD_CALL = "Error in unholding call: call is not on hold"
    static let ERROR_IN_HOLD_CALL = "Error in holding call: call is already on hold"
    static let ERROR_IN_SENDING_DIGIT = "Error in sending digits: digits length cannot be more than 24"
    static let ERROR_IN_SENDING_INVALID_DIGIT = "Invalid DTMF digit "
    static let ERROR_IN_SENDING_DIGIT_CALL_IS_HOLD = "Error in sending digits: call is onhold"
    
    static let DEBUG_LOGIN_FAILED_EVENT = "Delegate event : PlivoEndpointDelegate.onLoginFailedWithError(error:Error)/onLoginFailed()"
    static let DEBUG_ONINCOMING_CALL_EVENT = "Delegate event : PlivoEndpointDelegate.onIncomingCall(incoming:PlivoIncoming)"
    static let DEBUG_ONINCOMING_CALL_INVALID_EVENT = "Delegate event : PlivoEndpointDelegate.onIncomingCallInvalid(incoming:PlivoIncoming)"
    static let DEBUG_ONINCOMING_CALL_ANSWERED_EVENT = "Delegate event : PlivoEndpointDelegate.onIncomingCallAnswered(incoming:PlivoIncoming)"
    static let DEBUG_ONINCOMING_CALL_REJECTED_EVENT = "Delegate event : PlivoEndpointDelegate.onIncomingCallRejected(incoming:PlivoIncoming)"
    static let DEBUG_ONINCOMING_CALL_HANGUP_EVENT = "Delegate event : PlivoEndpointDelegate.onIncomingCallHangup(incoming:PlivoIncoming)"
    static let DEBUG_ONOUTGOING_CALL_ONCALLING_EVENT = "Delegate event : PlivoEndpointDelegate.onCalling(outgoing:PlivoOutgoing)"
    static let DEBUG_ONOUTGOING_CALL_RINGING_EVENT = "Delegate event : PlivoEndpointDelegate.onOutgoingCallRinging(outgoing:PlivoOutgoing)"
    static let DEBUG_ONOUTGOING_CALL_ANSWERED_EVENT = "Delegate event : PlivoEndpointDelegate.onOutgoingCallAnswered(outgoing:PlivoOutgoing)"
    static let DEBUG_ONOUTGOING_CALL_REJECTED_EVENT = "Delegate event : PlivoEndpointDelegate.onOutgoingCallRejected(outgoing:PlivoOutgoing)"
    static let DEBUG_ONOUTGOING_CALL_INVALID_EVENT = "Delegate event : PlivoEndpointDelegate.onOutgoingCallInvalid(outgoing:PlivoOutgoing)"
    static let DEBUG_ONOUTGOING_CALL_HANGUP_EVENT = "Delegate event : PlivoEndpointDelegate.onOutgoingCallHangup(outgoing:PlivoOutgoing)"
    static let DEBUG_ONLOGIN_EVENT = "Delegate event : PlivoEndpointDelegate.onLogin()"
    static let DEBUG_ONLOGOUT_EVENT = "Delegate event : PlivoEndpointDelegate.onLogout()"
    static let DEBUG_FEEDBACKALIDATION_ERROR_EVENT = "Delegate event : PlivoEndpointDelegate.onFeedbackValidationError(error:Error)"
    static let DEBUG_FEEDBACKALIDATION_SUCCESS_EVENT = "Delegate event : PlivoEndpointDelegate.onFeedbackSuccess(status:Int)"
    static let DEBUG_FEEDBACKALIDATION_FAUILER_EVENT = "Delegate event : PlivoEndpointDelegate.onFeedbackFailure(error:Error)"
    static let DEBUG_MEDIA_METRICES_EVENT = "Delegate event : PlivoEndpointDelegate.mediaMetrics(data:Dictionary)"
    
    static let REG_TIMEOUT_ERROR = "Allowed values of regTimeout should be in between 120 and 2592000 seconds only"
    static let REG_INVALID_TIMEOUT = "Invalid Registration Timeout"
    static let REG_INVALID_TIMEOUT_CODE = 292
    
    static let INVALID_ACCESS_TOKEN = "INVALID_ACCESS_TOKEN"
    static let INVALID_ACCESS_TOKEN_GRANTS = "INVALID_ACCESS_TOKEN_GRANTS"
}


enum CallState {
    case INV_STATE_CALLING
    case INV_STATE_EARLY
    case INV_STATE_CONNECTING
    case INV_STATE_CONFIRMED
    case INV_STATE_DISCONNECTED
}

enum TerminatedReason:String{
    case Error = "Error"
    case Timeout = "Timeout "
    case Replaced = "Replaced"
    case LocalBye = "LocalBye"
    case RemoteBye = "RemoteBye"
    case LocalCancel = "LocalCancel"
    case RemoteCancel = "RemoteCancel"
    case Rejected = "Rejected"
    case Referred = "Referred"
}

enum OtherReason:String{
    case EarlyMedia = "EarlyMedia"
    case Calling = "Calling"
    case CallAccepted = "CallAccepted"
    case Connecting = "Connecting"
}
