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

//    @objc static public var statsApiUrl: URL? {
//        let urlString = Bundle(for: self).infoDictionary?["STATS_API_URL"] as? String ?? "NA"
//        return URL(string:urlString)
//    }
//
//    @objc static public var statsSocketUrl: URL? {
//        let urlString = Bundle(for: self).infoDictionary?["STATSSOCKET_URL"] as? String ?? "NA"
//        return URL(string:urlString)
//    }
//
//    @objc static public var s3BucketApiUrl: URL? {
//        let urlString = Bundle(for: self).infoDictionary?["S3BUCKET_API_URL"] as? String ?? "NA"
//        return URL(string: urlString)
//    }
//
//    @objc static public var s3DumpUrl: URL? {
//        let urlString = Bundle(for: self).infoDictionary?["S3DUMPURL"] as? String ?? "NA"
//        return URL(string: urlString)
//    }

    @objc static public var bundleId: String {
        let id = Bundle(for: self).infoDictionary?["CFBundleIdentifier"] as? String ?? "NA"
        return id
    }

}
