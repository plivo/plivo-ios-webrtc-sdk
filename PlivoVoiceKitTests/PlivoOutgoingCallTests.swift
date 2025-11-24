//
//  PlivoOutgoingCallTests.swift
//  PlivoVoiceKitTests
//
//  Created by Krishna Thakur on 25/08/21.
//

import XCTest
@testable import PlivoVoiceKit
class PlivoOutgoingCallTests: XCTestCase, PlivoEndpointDelegate {
    
    var endpoint:PlivoEndpoint?
    var out:PlivoOutgoing?
    
    private var dailingProcessExpectation: XCTestExpectation?
    private var ringingProcessExpectation: XCTestExpectation?
    private var invalidUriProcessExpectation: XCTestExpectation?
    
    private var loginProcessExpectation: XCTestExpectation?
//    private var callResult: String?
    private var loginResult: String?
    private var state:PlivoCallState = .Terminated
    
    override func setUp() {
        super.setUp()
        endpoint = PlivoEndpoint(["debug":true,"enableTracking":true])
        endpoint?.delegate = self
        endpoint?.login("testusername", andPassword: "testpassword")
        loginProcessExpectation = XCTestExpectation(description: "Login")
        out = endpoint?.createOutgoingCall()
    }
    
    override func tearDown() {
        endpoint?.delegate = nil
        endpoint?.resetEndpoint()
        endpoint = nil
        state = .Terminated
        out = nil
        super.tearDown()
    }
    
    //Nil Case
    func testPlivoEndPoint_ObjectInit_ShouldNotBeNil() throws{
        XCTAssertNotNil(endpoint, "endpoint object should not be nil")
        XCTAssertNotNil(endpoint?.delegate, "endpoint delegate object should not be nil")
        XCTAssertNotNil(out, "outgoing call object should not be nil")
    }
    
    func testPlivoOutgoing_CheckCallDailingState_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("testusername")
        dailingProcessExpectation = XCTestExpectation(description: "DAIL")
        
        let result = XCTWaiter().wait(for: [dailingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Dialing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }

        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingState_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("+91xxxxxxxxxx")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
        
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
//        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckEmptySipURI_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("")
        
        ringingProcessExpectation = XCTestExpectation(description: "RING")
        
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTFail("Call should not initialized")
        case .timedOut:     XCTAssertTrue(out?.callId == "", "Call not started")
        default:            XCTAssertTrue(out?.callId == "", "Call not started")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithSipDomainInfo_ShouldReturnTrue() throws{
//        wait(for: [loginProcessExpectation!], timeout: 10)
//        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
//       
//        out?.call("sip:+91xxxxxxxxxx@phone.plivo.com")
//        ringingProcessExpectation = XCTestExpectation(description: "RING")
//        
//        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
//        
//        switch result {
//        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
//        case .timedOut:     XCTFail("Call not initialized")
//        default:            XCTFail("Call not initialized")
//        }
//        
//        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithPSTNCase1_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("sip:xxxxxxxxxx@phone.plivo.com")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
        
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTAssertTrue(state == .Terminated, "Call not started")
        default:            XCTAssertTrue(state == .Terminated, "Call not started")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithPSTNCase2_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("+91xxxxxxxxxx")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
        
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTAssertTrue(state == .Terminated, "Call not started")
        default:            XCTAssertTrue(state == .Terminated, "Call not started")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithPSTNCase3_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("+91xxxxxxxxxx")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
        
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithSipInfo_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("sip:+91xxxxxxxxxx")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
        
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithDomainInfo_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("+91xxxxxxxxxx@phone.plivo.com")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
       
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithInvalidCase1Info_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call(":+91xxxxxxxxxx@phone.plivo.com")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
   
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithInvalidCase2Info_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call(":+91xxxxxxxxxx@")
        
        ringingProcessExpectation = XCTestExpectation(description: "RING")
     
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithInvalidCase3Info_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call(":+91xxxxxxxxxx:phone.plivo.com")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
       
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTFail("Call should not initialized")
        case .timedOut:     XCTAssertTrue(out?.callId == "", "Call not started")
        default:            XCTAssertTrue(out?.callId == "", "Call not started")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithInvalidCase4Info_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("@+91xxxxxxxxxx@")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
     
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTFail("Call should not initialized")
        case .timedOut:     XCTAssertTrue(out?.callId == "", "Call not started")
        default:            XCTAssertTrue(out?.callId == "", "Call not started")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithInvalidCase5Info_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call(":@")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
       
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTFail("Call should not initialized")
        case .timedOut:     XCTAssertTrue(out?.callId == "", "Call not started")
        default:            XCTAssertTrue(out?.callId == "", "Call not started")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallMute_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        
        out?.call("+91xxxxxxxxxx")
        
        ringingProcessExpectation = XCTestExpectation(description: "RING")
       
        wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        out?.mute()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callMuted == true)
        
//        out?.hangup()
    }
    
    
    func testPlivoOutgoing_CheckCallUnMute_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        
        out?.call("+91xxxxxxxxxx")
        
        ringingProcessExpectation = XCTestExpectation(description: "RING")
       
        wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        out?.unmute()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callMuted == false)
        out?.hangup()
    }
    
    
    func testPlivoOutgoing_CheckCallUnHold_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        
        out?.call("+91xxxxxxxxxx")
        
        ringingProcessExpectation = XCTestExpectation(description: "RING")
       
        wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        out?.unhold()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callHolded == false)
        
        out?.hangup()
    }
    
    
    func testPlivoOutgoing_CheckRingingWithHeader_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")

        let header = ["X-Ph-AdvisorID":"001"]
        out?.call("+91xxxxxxxxxx", headers: header)
        ringingProcessExpectation = XCTestExpectation(description: "RING")

        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)

        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }

        out?.hangup()
    }
    
    func onLogin() {
        loginProcessExpectation?.fulfill()
        loginResult = "Login Success"
    }
    
    func onLoginFailedWithError(_ error: Error) {
        loginProcessExpectation?.fulfill()
        loginResult = error.localizedDescription
    }
    
    func onCalling(_ call: PlivoOutgoing){
        state = call.state ?? .Terminated
        dailingProcessExpectation?.fulfill()
    }
    
    func onOutgoingCallAnswered(_ call: PlivoOutgoing){
        state = call.state ?? .Terminated
    }
    
    func onOutgoingCallRinging(_ call: PlivoOutgoing){
        state = call.state ?? .Terminated
        ringingProcessExpectation?.fulfill()
    }
    
    func onOutgoingCallRejected(_ call: PlivoOutgoing){
        state = call.state ?? .Terminated
    }
    
    func onOutgoingCallInvalid(_ call: PlivoOutgoing){
        state = call.state ?? .Terminated
    }
    
    func onOutgoingCallHangup(_ call: PlivoOutgoing){
        state = call.state ?? .Terminated
    }
}
