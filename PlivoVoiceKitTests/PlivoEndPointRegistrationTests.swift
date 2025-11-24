//
//  PlivoVoiceKitTests.swift
//  PlivoVoiceKitTests
//
//  Created by Krishna Thakur on 24/08/21.
//

import XCTest
@testable import PlivoVoiceKit

class PlivoEndPointRegistrationTests: XCTestCase, PlivoEndpointDelegate {
    
    var endpoint:PlivoEndpoint?
    private var loginExpectation: XCTestExpectation?
    private var results: String?
    
    override func setUp() {
        super.setUp()
        print("setup object")
        endpoint = PlivoEndpoint(["debug":true,"enableTracking":true])
        endpoint?.delegate = self
    }
    
    override func tearDown() {
        print("tearDown object")
        endpoint?.delegate = nil
        endpoint?.resetEndpoint()
        endpoint = nil
        super.tearDown()
    }
    
    //Nil Case
    func testPlivoEndPoint_ObjectInit_ShouldNotBeNil() throws{
        XCTAssertNotNil(endpoint, "endpoint object should not be nil")
        XCTAssertNotNil(endpoint?.delegate, "endpoint delegate object should not be nil")
    }
    func testPlivoEndPoint_WhenUserNamePasswordProvided_UsernamePasswordShouldBeCorrect() throws {
        loginExpectation = XCTestExpectation(description: "")

        endpoint?.login("testusername", andPassword: "testpassword")
        wait(for: [loginExpectation!], timeout: 10)

        XCTAssertTrue(results == "Login Success", "Registeration success")
    }
//    
//    //Fail case : empty user name
    func testPlivoEndPoint_WhenUserNameNil_UsernameValidationShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("", andPassword: "testpassword")
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_1, "username should not be nil")
    }
//    
//    //Fail case : empty password
    func testPlivoEndPoint_WhenPasswordNil_PasswordValidationShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testusername", andPassword: "")
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_1, "password should not be nil")
    }
//    
//    //Fail case : registration timeout is below the limit
    func testPlivoEndPoint_WhenRegTimeoutisLessThanfLimit_InValidRegTimeout() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testusername", andPassword: "testpassword", regTimeout: 5)
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.REG_INVALID_TIMEOUT, "registration timeout should be grater than 120 and less than 86400")
    }
//    
//    //Fail case : registration timeout is above the limit
    func testPlivoEndPoint_WhenRegTimeoutisGreaterThanfLimit_InValidRegTimeout() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testusername", andPassword: "testpassword", regTimeout: 86500)
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.REG_INVALID_TIMEOUT, "registration timeout should be grater than 120 and less than 86400")
    }
//    //Fail case : registration timeout called without username and password
    func testPlivoEndPoint_WhenRegTimeoutisValidButCredentialsMissing_UsernamePasswordShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("", andPassword: "", regTimeout: 56400)
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_1, "username and password should not be nil")
    }
//    //Fail case : username and password is given but device token is nil
    func testPlivoEndPoint_DeviceTokenIsNil_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testusername", andPassword: "testpassword", deviceToken: nil)
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_2, "device token should not be nil")
    }
//    
//    //Fail case : username is nil but password and device token is given
    func testPlivoEndPoint_UserNameIsNilDeviceTokenNotNil_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("", andPassword: "testpassword", deviceToken: "xxxxxxxxxx".data(using: .utf8))
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_2, "username should not be nil")
    }
//    
//    //Fail case : username and device token is given but password is nil
    func testPlivoEndPoint_PasswordIsNilDeviceTokenNotNil_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testusername", andPassword: "", deviceToken: "xxxxxxxxxx".data(using: .utf8))
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_2, "password should not be nil")
    }
//    //Fail case : username password device token is given but certificate id is nil
    func testPlivoEndPoint_CertIdIsNil_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testusername", andPassword: "testpassword", deviceToken: "xxxxxxxxxx".data(using: .utf8),certificateId: "")
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_3, "certificate id should not be nil")
    }
//    
//    //Fail case : username password is given but certificate id and device token is nil
    func testPlivoEndPoint_CertIdAndDeviceTokenIsNil_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testusername", andPassword: "testpassword", deviceToken: nil ,certificateId: "")
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_3, "certificate id and device token should not be nil")
    }
//    //Fail case : register device token called without login
    func testPlivoEndPoint_RegisterDeviceTokenBeforeLogin_RegisterTokenShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.registerToken("xxxxxxxxxx".data(using: .utf8)!)
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_2, "register device token called before login")
    }
//    //Fail case : register username with invalid sip url
    func testPlivoEndPoint_RegisterWithCase1_RegisterTokenShouldSuccess() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("@testusername@", andPassword: "testpassword")

        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.INVALID_SIP_USERNAME, "auto correction of sip uri")
    }
//    //Success case : register username with invalid sip url
    func testPlivoEndPoint_RegisterWithCase3_RegisterTokenShouldSuccess() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login(":@", andPassword: "testpassword")

        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.INVALID_SIP_USERNAME, "auto correction of sip uri")
    }
//    
//    //Success case : register username with invalid sip url
    func testPlivoEndPoint_RegisterWithCase4_RegisterTokenShouldSuccess() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login(":testusername:phone.plivo.com", andPassword: "testpassword")
        
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.INVALID_SIP_USERNAME, "auto correction of sip uri")
    }
    
    func onLogin() {
        loginExpectation?.fulfill()
        results = "Login Success"
    }
    
    func onLoginFailedWithError(_ error: Error) {
        loginExpectation?.fulfill()
        results = error.localizedDescription
    }
    
}