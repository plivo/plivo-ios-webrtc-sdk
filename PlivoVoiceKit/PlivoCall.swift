//
//  PlivoCall.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 04/02/21.
//

import Foundation


public typealias PlivoCallId = String
public typealias PlivoAccId = Int

@objc public enum PlivoCallState : Int {
    case Dialing = 0
    case Ringing
    case Ongoing
    case Terminated
}

public private(set) var Dialing: PlivoCallState = .Dialing
public private(set) var Ringing: PlivoCallState = .Ringing
public private(set) var Ongoing: PlivoCallState = .Ongoing
public private(set) var Terminated: PlivoCallState = .Terminated
