//
//  Utils.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 11/02/21.
//

import Foundation
import SystemConfiguration
//import CoreTelephony

class Utils {
    
    static var DEBUGFLAG = false
    static var ANSWERBEFORECALLID = false
    static var REJECTBEFORECALLID = false
    static var INVITEBEFORECALLID = false
    static var IS_CALL_RUNNING = false
    
    class func error(withMessage msg: String?, code: Int) -> NSError? {
        let userInfo = [
            NSLocalizedDescriptionKey: msg ?? ""
        ]
        let error = NSError(domain: Environment.bundleId, code: code, userInfo: userInfo)
        return error
    }
    
    class func isNetworkAvailable() -> Bool {
        var flags = SCNetworkReachabilityFlags()
        var address: SCNetworkReachability?
        address = SCNetworkReachabilityCreateWithName(nil, "www.google.com")
        var success: Bool? = nil
        if let address = address {
            success = SCNetworkReachabilityGetFlags(address, &flags)
        }

        let canReach = success ?? false && (flags.rawValue & SCNetworkReachabilityFlags.connectionRequired.rawValue) == 0 && (flags.rawValue & SCNetworkReachabilityFlags.reachable.rawValue) != 0

        return canReach
    }
    
    class func setDebugFlag(_ isDebug: Bool) {
        DEBUGFLAG = isDebug
    }

    class func setAnswerFlag(_ didTry: Bool) {
        ANSWERBEFORECALLID = didTry
    }

    class func getAnswerFlag() -> Bool {
        return ANSWERBEFORECALLID
    }

    class func setRejectFlag(_ didTry: Bool) {
        REJECTBEFORECALLID = didTry
    }

    class func getRejectFlag() -> Bool {
        return REJECTBEFORECALLID
    }

    class func setInviteFlag(_ didTry: Bool) {
        INVITEBEFORECALLID = didTry
    }

    class func getInviteFlag() -> Bool {
        return INVITEBEFORECALLID
    }
    
    class func getCurrentTimeInMilliSeconds() -> NSNumber {
        let time = Date().timeIntervalSince1970
        let digits = Int(time)
        let decimalDigits = Int(fmod(time, 1) * 1000)
        let timestamp = (digits * 1000) + decimalDigits
        return NSNumber(value: timestamp)
    }
    
    
    class func convertDict(toJSON dict: [String : Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else{ return ""}
        
        let str = String(data: data, encoding: String.Encoding.utf8) ?? ""
        return str
    }
    
    class func getConnectionType() -> String {
        guard let reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "www.google.com") else {
            return "no-internet"
        }

        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability, &flags)

        let isReachable = flags.contains(.reachable)
        let isWWAN = flags.contains(.isWWAN)

        if isReachable {
            if isWWAN {
                return "mobile"
//                let networkInfo = CTTelephonyNetworkInfo()
//                if #available(iOS 12.0, *) {
//                    let carrierType = networkInfo.serviceCurrentRadioAccessTechnology
//                    guard let carrierTypeName = carrierType?.first?.value else {
//                        return "UNKNOWN"
//                    }
//
//                    switch carrierTypeName {
//                    case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
//                        return "2G"
//                    case CTRadioAccessTechnologyLTE:
//                        return "4G"
//                    default:
//                        return "3G"
//                    }
//                } else {
//                    // Fallback on earlier versions
//                }
            } else {
                return "wifi"
            }
        } else {
            return "no-internet"
        }
    }
    
}

extension Data {
    var bytes : [UInt8]{
        return [UInt8](self)
    }
}
