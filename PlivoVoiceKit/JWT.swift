//
//  JWT.swift
//  PlivoVoiceKit
//
//  Created by Sanyam Jain on 23/06/22.
//

import Foundation


struct JWT: Codable {
    var iss: String
    var sub: String?
    var per: Permission?
    var app: String?
    var nbf: Int
    var exp: Int
}

struct Permission: Codable {
    var voice: Voice?
}

struct Voice: Codable {
    var incoming_allow: Bool?
    var outgoing_allow: Bool?
}
