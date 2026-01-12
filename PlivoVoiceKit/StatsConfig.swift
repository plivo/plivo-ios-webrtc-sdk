//
//  StatsConfig.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 21/04/21.
//

import Foundation

struct StatsConfig {
    static var username: String?
    static var password: String?
    static var access_token: String?
    static var stats_key: String?
    static var call_uuid: String?
    static var token:String?
    static var cert_id:String?
    static var last_xcall_uuid: String?
    static var msg: String?
    static var info: String?
    static var answer_time: NSNumber?
    static var call_confirmed_time: NSNumber?
    static var call_initiation_time: NSNumber?
    static var hangup_party: String? = nil
    static var hangup_reason: String? = nil
    static var hangup_time: NSNumber? = nil
    static var postDialDelayEndTime: NSNumber? = nil
    static var ring_start_time: NSNumber? = nil
    static var call_progress_time: NSNumber? = nil
    static var x_call_uuid: String? = nil
    static var last_call_uuid: String? = nil
    static var last_stats_key: String? = nil
    static var rtp_enabled: Bool = false
}
