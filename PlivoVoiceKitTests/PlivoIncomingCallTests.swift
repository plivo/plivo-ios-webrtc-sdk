//
//  PlivoIncomingCallTests.swift
//  PlivoVoiceKitTests
//
//  Created by Krishna Thakur on 22/09/21.
//

import XCTest
@testable import PlivoVoiceKit

class PlivoIncomingCallTests: XCTestCase, PlivoEndpointDelegate {
    
    var endpoint:PlivoEndpoint?
    var incoming:PlivoIncoming?
    
    private var loginResult: String?
    
    private var loginProcessExpectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        endpoint = PlivoEndpoint(["debug":true,"enableTracking":true])
        endpoint?.delegate = self
        endpoint?.login("testiosendpoint", andPassword: "testpassword")
        loginProcessExpectation = XCTestExpectation(description: "Login")
    }
    
    override func tearDown() {
        endpoint?.delegate = nil
        endpoint?.resetEndpoint()
        endpoint = nil
        super.tearDown()
    }
    
    func testPlivoIncoming_ProxyRegister_ShouldSuccess() throws{
        let payload =  [AnyHashable("aps"):
                            ["alert" : "plivo",
                             "callerID" : "sip:<sample caller id>",
                             "extraHeaders" : "X-PH-conference: true",
                             "index" : 22930,
                             "label" : 657315173,
                             "registrar" : "52.9.254.127",
                             "sound" : "default"]
                        ]
        endpoint?.relayVoipPushNotification(payload)
        
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
    }
   
    func onLogin() {
        loginProcessExpectation?.fulfill()
        loginResult = "Login Success"
    }
    
    func onLoginFailedWithError(_ error: Error) {
        loginProcessExpectation?.fulfill()
        loginResult = error.localizedDescription
    }
    
}
