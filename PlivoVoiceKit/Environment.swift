//
//  EnvConfig.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 24/06/21.
//

import Foundation

@objc open class Environment:NSObject {
    
    public override init() {
        LogManager.shared.log("init Environment", level: .notice)
    }
    
    deinit {
        LogManager.shared.log("deinit Environment", level: .notice)
    }
    
    @objc static public var sipDomain: String {
//        let domain = Bundle(for: self).infoDictionary?["SIP_DOMAIN"] as? String
        return Constant.DOMAIN
    }
    
    @objc static public var proxy: String {
//        let domain = Bundle(for: self).infoDictionary?["SIP_DOMAIN"] as? String
        return Constant.OUTBOUND_PROXY
    }
    
    @objc static public var FALLBACK_PROXY: String {
//        let domain = Bundle(for: self).infoDictionary?["SIP_DOMAIN"] as? String
        return Constant.FALLBACK_PROXY
    }
    
    
    @objc static public var bundleId: String {
        let id = Bundle(for: self).infoDictionary?["CFBundleIdentifier"] as? String ?? "NA"
        return id
    }
    
    @objc static public var userAgent: String {
        print("user-agent is \(Constant.SDK_NAME)-v\(Constant.PLIVO_ENDPOINT_VER)")
        return "\(Constant.SDK_NAME)-v\(Constant.PLIVO_ENDPOINT_VER)"
    }
    
}
