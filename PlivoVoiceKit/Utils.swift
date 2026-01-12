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
    
    class func jwtDecode(jwtToken jwt: String) -> [String: Any] {
      let segments = jwt.components(separatedBy: ".")
        if (segments.count > 1) {
            return decodeJWTPart(segments[1]) ?? [:]
        }
        return [:]
    }

    class func base64UrlDecode(_ value: String) -> Data? {
      var base64 = value
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")

      let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
      let requiredLength = 4 * ceil(length / 4.0)
      let paddingLength = requiredLength - length
      if paddingLength > 0 {
        let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
        base64 = base64 + padding
      }
      return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
    }

    class func decodeJWTPart(_ value: String) -> [String: Any]? {
      guard let bodyData = base64UrlDecode(value),
        let json = try? JSONSerialization.jsonObject(with: bodyData, options: []), let payload = json as? [String: Any] else {
          LogManager.shared.infoLogs(log: "Login | failed: Error while decoding access token")
          return nil
      }

      return payload
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
            } else {
                return "wifi"
            }
        } else {
            return "no-internet"
        }
    }
    
    class func getDeviceName() -> String {
        return UIDevice.current.name
    }
    
    class func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    class func getModel() -> String {
        return UIDevice.current.model
    }
    
    class func getlocalizedModel() -> String {
        return UIDevice.current.localizedModel
    }
    
    class func getSystemName() -> String {
        return UIDevice.current.systemName
    }
    
    func getIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name: String = String(cString: (interface.ifa_name))
                    if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address ?? ""
    }
    
}

extension Data {
    var bytes : [UInt8]{
        return [UInt8](self)
    }
}
