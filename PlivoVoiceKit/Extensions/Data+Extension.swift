//
//  DataExtension.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 15/02/21.
//

import Foundation

extension Data {
    var hexString: String {
        let hexString = map { String(format: "%02.2hhx", $0) }.joined()
        return hexString
    }
}
