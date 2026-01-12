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
    var outgoingEndpoint = "<sample outgoing endpoint>"
    
    private var dailingProcessExpectation: XCTestExpectation?
    private var ringingProcessExpectation: XCTestExpectation?
    private var answeredCallProcessExpectation: XCTestExpectation?
    private var invalidUriProcessExpectation: XCTestExpectation?
    
    private var loginProcessExpectation: XCTestExpectation?
//    private var callResult: String?
    private var loginResult: String?
    private var state:PlivoCallState = .Terminated
    private var jwtParams: [String: Any] = [:]
    
    override func setUp() {
        super.setUp()
        endpoint = PlivoEndpoint(["debug":true,"enableTracking":true])
        endpoint?.delegate = self
        endpoint?.login("testiosendpoint", andPassword: "testpassword")
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
       
        out?.call("<sample outgoing endpoint>")
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
        wait(for: [loginProcessExpectation!], timeout: 20)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call(outgoingEndpoint)
        ringingProcessExpectation = XCTestExpectation(description: "RING")
        
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
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
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")

        out?.call("sip:\(outgoingEndpoint)@phone.plivo.com")
        ringingProcessExpectation = XCTestExpectation(description: "RING")

        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)

        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }

        out?.hangup()
    }
    
    /*
     Duplicate: Same as Above
     */
    func testPlivoOutgoing_CheckCallRingingWithPSTNCase1_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("sip:\(outgoingEndpoint)@phone.plivo.com")
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
       
        out?.call("<sample outgoing endpoint>")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
        
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTAssertTrue(state == .Terminated, "Call not started")
        default:            XCTAssertTrue(state == .Terminated, "Call not started")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithSipInfo_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call("sip:\(outgoingEndpoint)")
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
       
        out?.call("\(outgoingEndpoint)@phone.plivo.com")
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
       
        out?.call(":\(outgoingEndpoint)@phone.plivo.com")
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
       
        out?.call(":\(outgoingEndpoint)@")
        
        ringingProcessExpectation = XCTestExpectation(description: "RING")
     
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallScenerioForCallNotInitiated_removed() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        
        let isCallInitiated1 = out?.call("")
        XCTAssertTrue(isCallInitiated1 == false)
        
        let isCallInitiated2 = out?.call("@@@<sample outgoing endpoint>@@@3444#")
        XCTAssertTrue(isCallInitiated2 == false)
       
        out?.call("\(outgoingEndpoint)")
        answeredCallProcessExpectation = XCTestExpectation(description: "ANSWER")
        let result = XCTWaiter().wait(for: [answeredCallProcessExpectation!], timeout: 15.0)
        
        let isCallInitiated = out?.call(":\(outgoingEndpoint)@")
        XCTAssertTrue(isCallInitiated == false)

        switch result {
        case .completed:    XCTAssertTrue(state == .Ongoing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
    
    }

    
    
    func testPlivoOutgoing_CheckCallRingingWithInvalidCase3Info_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
       
        out?.call(":\(outgoingEndpoint):phone.plivo.com")
        ringingProcessExpectation = XCTestExpectation(description: "RING")
       
        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        switch result {
        case .completed:    XCTFail("Call should not initialized")
        case .timedOut:     XCTAssertTrue(out?.callId == "", "Call not started")
        default:            XCTAssertTrue(out?.callId == "", "Call not started")
        }
        
        out?.hangup()
    }
    
    
    func testPlivoOutgoing_CheckCallScenerioForCallNotInitiatedWithErrorArgs_removed() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        
        var error: NSError? = nil
        
        let isCallInitiated1 = out?.call("", error: &error)
        XCTAssertTrue(isCallInitiated1 == false)
        
        let isCallInitiated2 = out?.call("@@@<sample outgoing endpoint>@@@3444#", error: &error)
        XCTAssertTrue(isCallInitiated2 == false)
       
        out?.call("\(outgoingEndpoint)", error: &error)
        answeredCallProcessExpectation = XCTestExpectation(description: "ANSWER")
        let result = XCTWaiter().wait(for: [answeredCallProcessExpectation!], timeout: 15.0)
        
        let isCallInitiated = out?.call(":\(outgoingEndpoint)@", error: &error)
        XCTAssertTrue(isCallInitiated == false)

        switch result {
        case .completed:    XCTAssertTrue(state == .Ongoing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
    }
    
    
    func testPlivoOutgoing_CheckCallScenerioForCallWithHeader_removed() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        
        let headers: [AnyHashable: Any] = [:]
        
        let isCallInitiated1 = out?.call("", headers: headers)
        XCTAssertTrue(isCallInitiated1 == false)
        
        let isCallInitiated2 = out?.call("@@@<sample outgoing endpoint>@@@3444#", headers: headers)
        XCTAssertTrue(isCallInitiated2 == false)
        
        let headers2: [AnyHashable: Any] = [
            1 : "application/json"
        ]
        let isCallInitiated3 = out?.call(":\(outgoingEndpoint)@", headers: headers2)
        XCTAssertTrue(isCallInitiated3 == false)
        
       
        out?.call("\(outgoingEndpoint)", headers: headers)
        answeredCallProcessExpectation = XCTestExpectation(description: "ANSWER")
        let result = XCTWaiter().wait(for: [answeredCallProcessExpectation!], timeout: 15.0)
        
        let isCallInitiated = out?.call(":\(outgoingEndpoint)@", headers: headers)
        XCTAssertTrue(isCallInitiated == false)
        
        let headers4: [AnyHashable: Any] = [
            "Cssse": "esxampleTest"
        ]
        let isCallInitiated5 = out?.call(":\(outgoingEndpoint)@", headers: headers4)
        XCTAssertTrue(isCallInitiated5 == false)

        
       


        switch result {
        case .completed:    XCTAssertTrue(state == .Ongoing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallScenerioForCallWithHeaderAndError_removed() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        
        var error: NSError? = nil
        let headers: [AnyHashable: Any] = [:]
        
        let isCallInitiated1 = out?.call("", headers: headers, error: &error)
        XCTAssertTrue(isCallInitiated1 == false)
        
        let isCallInitiated2 = out?.call("@@@<sample outgoing endpoint>@@@3444#", headers: headers, error: &error)
        XCTAssertTrue(isCallInitiated2 == false)
        
        let headers2: [AnyHashable: Any] = [
            1 : "application/json"
        ]
        let isCallInitiated3 = out?.call(":\(outgoingEndpoint)@", headers: headers2, error: &error)
        XCTAssertTrue(isCallInitiated3 == false)
        
       
        out?.call("\(outgoingEndpoint)", headers: headers, error: &error)
        answeredCallProcessExpectation = XCTestExpectation(description: "ANSWER")
        let result = XCTWaiter().wait(for: [answeredCallProcessExpectation!], timeout: 15.0)
        
        let isCallInitiated = out?.call(":\(outgoingEndpoint)@", headers: headers, error: &error)
        XCTAssertTrue(isCallInitiated == false)
        
        let headers4: [AnyHashable: Any] = [
            "Cssse": "esxampleTest"
        ]
        let isCallInitiated5 = out?.call(":\(outgoingEndpoint)@", headers: headers4, error: &error)
        XCTAssertTrue(isCallInitiated5 == false)

        
       


        switch result {
        case .completed:    XCTAssertTrue(state == .Ongoing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }
        
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallRingingWithInvalidCase4Info_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")

        out?.call("@\(outgoingEndpoint)@")
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
    
    
    
    
    func testPlivoOutgoing_CheckCallMuteUnMuteHoldUnHold_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 20)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        
        out?.call("\(outgoingEndpoint)")
        
        ringingProcessExpectation = XCTestExpectation(description: "RING")
       
        wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        out?.mute()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callMuted == true)
        out?.unmute()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callMuted == false)
        out?.hold()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callHolded == false)
        out?.unhold()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callHolded == false)
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallSendDigitInRingingState_ShouldReturnFalse() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        
        out?.call("\(outgoingEndpoint)")
        
        ringingProcessExpectation = XCTestExpectation(description: "RING")
       
        wait(for: [ringingProcessExpectation!], timeout: 10.0)
        
        let isDigitSent = out?.sendDigits("1")
        XCTAssertTrue(isDigitSent == false)
        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallOnCallMuteUnMuteHoldUnHold_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        
        out?.call("\(outgoingEndpoint)")
        
        answeredCallProcessExpectation = XCTestExpectation(description: "ANSWER")
       
        wait(for: [answeredCallProcessExpectation!], timeout: 16.0)
        
        out?.mute()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callMuted == true)
        out?.unmute()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callMuted == false)
        out?.hold()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callHolded == true)
        out?.unhold()
        XCTAssertTrue(out!.webrtcAdapter!.webRTCClient.callHolded == false)
        let isDigitSent = out?.sendDigits("1dfssdfrfdsfgsdgdsfgdfsfsfsdfsddsdasdasdasdasdasdasdadddddffffsssssddewsdewsdewsdewsderwsdewsdewsdewsdewsdewsdewsdewsddsewef")
        XCTAssertTrue(isDigitSent == false)
        let isDigitSent2 = out?.sendDigits("a")
        XCTAssertTrue(isDigitSent2 == false)
        let isDigitSent2 = out?.sendDigits("1")
        XCTAssertTrue(isDigitSent2 == true)
        out?.hangup()
    }
    
 
    
    
    
    func testPlivoOutgoing_CheckRingingWithHeader_ShouldReturnTrue() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")

        let header = ["X-Ph-AdvisorID":"001"]
        out?.call(outgoingEndpoint, headers: header)
        ringingProcessExpectation = XCTestExpectation(description: "RING")

        let result = XCTWaiter().wait(for: [ringingProcessExpectation!], timeout: 10.0)

        switch result {
        case .completed:    XCTAssertTrue(state == .Ringing, "Call in state other then RINGING")
        case .timedOut:     XCTFail("Call not initialized")
        default:            XCTFail("Call not initialized")
        }

        out?.hangup()
    }
    
    func testPlivoOutgoing_CheckCallWithJWT_ShouldAddHeaders() throws{
        wait(for: [loginProcessExpectation!], timeout: 10)
        endpoint?.resetEndpoint()
        loginProcessExpectation = XCTestExpectation(description: "")

        jwtParams["sub"] = "<sample jwt sub>"
        jwtParams["per"] = true
        jwtParams["outgoing_allow"] = true
        jwtParams["incoming_allow"] = true
        endpoint?.loginWithAccessTokenGenerator(jwtDelegate: self)
        wait(for: [loginProcessExpectation!], timeout: 10)
        XCTAssertTrue(loginResult == "Login Success", "auto correction of sip uri")
        out = endpoint?.createOutgoingCall()
        out?.call(outgoingEndpoint)
        XCTAssertTrue(out?.headers!["X-Plivo-Jwt"] != nil)

        out?.headers = nil
        var error: NSError? = nil
        out?.call(outgoingEndpoint, error: &error)
        XCTAssertTrue(out?.headers!["X-Plivo-Jwt"] != nil)

        dailingProcessExpectation = XCTestExpectation(description: "DAIL")

        out?.headers = nil
        out?.call("<sample jwt sub>")

        let result = XCTWaiter().wait(for: [dailingProcessExpectation!], timeout: 10.0)

        switch result {
        case .completed:    XCTAssertTrue(state == .Dialing, "Call in state other then RINGING")
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
        answeredCallProcessExpectation?.fulfill()
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



extension PlivoOutgoingCallTests: JWTDelegate {
    func getAccessToken() {
        let Url = String(format: "https://api.plivo.com/v1/Account/<auth_id>/JWT/Token")
           guard let serviceUrl = URL(string: Url) else { return }
            let timeInterval = Int(Date().timeIntervalSince1970)
        var parameterDictionary: [String: Any] = [
                "iss": "<auth_id>",
            ]
        
        if jwtParams["sub"] != nil {
            parameterDictionary["sub"] = jwtParams["sub"]
        }
        
        if jwtParams["per"] != nil {
            parameterDictionary["per"] = ["voice": ["incoming_allow": jwtParams["incoming_allow"], "outgoing_allow": jwtParams["outgoing_allow"]]]
        }
           var request = URLRequest(url: serviceUrl)
           request.httpMethod = "POST"
           request.setValue("application/json", forHTTPHeaderField: "Content-Type")
           guard let httpBody = try? JSONSerialization.data(withJSONObject: parameterDictionary, options: []) else {
               return
           }
           request.httpBody = httpBody
        request.addValue("Basic <basic_auth_token>", forHTTPHeaderField: "Authorization")
           let session = URLSession.shared
           session.dataTask(with: request) { (data, response, error) in
               if let response = response {
                   print(response)
               }
               if let data = data {
                   do {
                       var _:String = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as! String

                       let token: JWTDecoder = try JSONDecoder().decode(JWTDecoder.self, from: data)
                       self.endpoint?.loginWithAccessToken(token.token)
                       
                   } catch let decoderError {
                       print(decoderError)
                   }
               }
              
           }.resume()
    }
}
