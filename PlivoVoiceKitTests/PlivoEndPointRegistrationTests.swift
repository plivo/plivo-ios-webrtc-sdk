//
//  PlivoVoiceKitTests.swift
//  PlivoVoiceKitTests
//
//  Created by Krishna Thakur on 24/08/21.
//

import XCTest
@testable import PlivoVoiceKit

class PlivoEndPointRegistrationTests: XCTestCase, PlivoEndpointDelegate {
    
    weak var endpoint:PlivoEndpoint?
    private var loginExpectation: XCTestExpectation?
    private var permissionExpectation: XCTestExpectation?
    private var results: String?
    private var jwtParams: [String: Any] = [:]
    
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
 
//    //Success case : correct user name and password
    func testPlivoEndPoint_WhenUserNamePasswordProvided_UsernamePasswordShouldBeCorrect() throws {
        loginExpectation = XCTestExpectation(description: "")

        endpoint?.login("testiosendpoint", andPassword: "testpassword")
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
        endpoint?.login("testiosendpoint", andPassword: "")
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_1, "password should not be nil")
    }
//    
//    //Fail case : registration timeout is below the limit
    func testPlivoEndPoint_WhenRegTimeoutisLessThanfLimit_InValidRegTimeout() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.setRegTimeout(regTimeout: 5)
        endpoint?.login("testiosendpoint", andPassword: "testpassword")
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.REG_INVALID_TIMEOUT, "registration timeout should be grater than 120 and less than 86400")
    }
//    
//    //Fail case : registration timeout is above the limit
    func testPlivoEndPoint_WhenRegTimeoutisGreaterThanfLimit_InValidRegTimeout() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.setRegTimeout(regTimeout: 2593000)
        endpoint?.login("testiosendpoint", andPassword: "testpassword")
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.REG_INVALID_TIMEOUT, "registration timeout should be grater than 120 and less than 2592000")
    }
//    
//    //Fail case : registration timeout called without username and password
    func testPlivoEndPoint_WhenRegTimeoutisValidButCredentialsMissing_UsernamePasswordShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.setRegTimeout(regTimeout: 56400)
        endpoint?.login("", andPassword: "")
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_1, "username and password should not be nil")
    }

//    //Fail case : username and password is given but device token is nil
    func testPlivoEndPoint_DeviceTokenIsNil_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testiosendpoint", andPassword: "testpassword", deviceToken: nil)
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_2, "device token should not be nil")
    }
//    
//    //Fail case : username is nil but password and device token is given
    func testPlivoEndPoint_UserNameIsNilDeviceTokenNotNil_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("", andPassword: "testpassword", deviceToken: Data())
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_2, "username should not be nil")
    }
//    
//    //Fail case : username and device token is given but password is nil
    func testPlivoEndPoint_PasswordIsNilDeviceTokenNotNil_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testiosendpoint", andPassword: "", deviceToken: Data())
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_2, "password should not be nil")
    }

//    //Fail case : username password device token is given but certificate id is nil
    func testPlivoEndPoint_CertIdIsNil_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testiosendpoint", andPassword: "testpassword", deviceToken: Data(),certificateId: "")
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_3, "certificate id should not be nil")
    }
//    
//    //Fail case : username password is given but certificate id and device token is nil
    func testPlivoEndPoint_CertIdAndDeviceTokenIsNil_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("testiosendpoint", andPassword: "testpassword", deviceToken: nil ,certificateId: "")
        wait(for: [loginExpectation!], timeout: 1)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_3, "certificate id and device token should not be nil")
    }

//    //Fail case : register device token called without login
    func testPlivoEndPoint_RegisterDeviceTokenBeforeLogin_RegisterTokenShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.registerToken(Data())
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.EMPTY_LOGIN_2, "register device token called before login")
    }

//    //Fail case : register username with invalid sip url
    func testPlivoEndPoint_RegisterWithCase1_RegisterTokenShouldSuccess() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.login("@testiosendpoint@", andPassword: "testpassword")

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
        endpoint?.login(":testiosendpoint:phone.plivo.com", andPassword: "testpassword")
        
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.INVALID_SIP_USERNAME, "auto correction of sip uri")
    }
    
    func onLogin() {
        loginExpectation?.fulfill()
        results = "Login Success"
    }
    
    func onLoginFailedWithError(_ error: Error) {
        loginExpectation?.fulfill()
        print("error is \(error.localizedDescription)")
        results = error.localizedDescription
    }
    
    func onPermissionDenied(_ error: Error) {
        permissionExpectation?.fulfill()
        results = error.localizedDescription
    }

    //MARK: - JWT test cases

    //Failure case: login with empty access token
    func testPlivoEndpoint_LoginWithJWTCase1_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")

        endpoint?.loginWithAccessToken("")
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.JWT_EMPTY_LOGIN_1, "login with empty access token")
    }

    //Failure case: login with accessToken and deviceToken
    func testPlivoEndpoint_LoginWithJWTCase2_LoginShouldFail() throws {
        //login with Empty accessToken
        loginExpectation = XCTestExpectation(description: "")

        endpoint?.loginWithAccessToken("", deviceToken: "dassfd".data(using: .utf8))
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.JWT_EMPTY_LOGIN_2, "login with accessToken and deviceToken")

        //login with nil  deviceToken
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.loginWithAccessToken("sadsdv", deviceToken: nil)
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.JWT_EMPTY_LOGIN_2, "login with accessToken and deviceToken")

        //login with empty accessToken and nil deviceToken
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.loginWithAccessToken("", deviceToken: nil)
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.JWT_EMPTY_LOGIN_2, "login with accessToken and deviceToken")
    }

    //Failure case: login with accessToken, deviceToken and certificateId
    func testPlivoEndpoint_LoginWithJWTCase3_LoginShouldFail() throws {
        //login with empty accessToken
        loginExpectation = XCTestExpectation(description: "")

        endpoint?.loginWithAccessToken("", deviceToken: "adsd".data(using: .utf8), certificateId: "adsfd")
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.JWT_EMPTY_LOGIN_3, "login with accessToken, deviceToken and certificateId")

        //login with nil deviceToken
        loginExpectation = XCTestExpectation(description: "")

        endpoint?.loginWithAccessToken("asdfdvf", deviceToken: nil, certificateId: "adsfd")
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.JWT_EMPTY_LOGIN_3, "login with accessToken, deviceToken and certificateId")

        //login with empty certificate id
        loginExpectation = XCTestExpectation(description: "")

        endpoint?.loginWithAccessToken("asdfdvf", deviceToken: "nil".data(using: .utf8), certificateId: "")
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.JWT_EMPTY_LOGIN_3, "login with accessToken, deviceToken and certificateId")

        //login with empty accessToken, deviceToken and certificateId
        loginExpectation = XCTestExpectation(description: "")

        endpoint?.loginWithAccessToken("", deviceToken: nil, certificateId: "")
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.JWT_EMPTY_LOGIN_3, "login with accessToken, deviceToken and certificateId")
    }

    //Failure case: User is already logged in
    func testPlivoEndpoint_LoginWithJWTCase4_LoginShouldFail() throws {
        loginExpectation = XCTestExpectation(description: "")
        jwtParams["sub"] = "test"

        endpoint?.loginWithAccessTokenGenerator(jwtDelegate: self)
        
        wait(for: [loginExpectation!], timeout: 10)

        print("initiating new registration")
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.loginWithAccessTokenGenerator(jwtDelegate: self)

        wait(for: [loginExpectation!], timeout: 10)
        print("result is \(self.results)")
        XCTAssertTrue(self.results == Constant.ALREADY_REGISTERED, "user already registered")
    }

    //Failure case: token validation
    func testPlivoEndpoint_LoginWithJWTCase5_LoginTokenValidation() throws {
        loginExpectation = XCTestExpectation(description: "")
        var jwtToken: String = "dasdvfvsddfsfg"
        //when the user is already registered
        endpoint?.loginWithAccessToken(jwtToken, deviceToken: "sdf".data(using: .utf8))
        wait(for: [loginExpectation!], timeout: 5)
        XCTAssertTrue(results == Constant.INVALID_ACCESS_TOKEN, "invalid access token")

        //when the iss is missing
        loginExpectation = XCTestExpectation(description: "")
        jwtToken = "<sample jwt token>"
        endpoint?.loginWithAccessToken(jwtToken, deviceToken: "sdf".data(using: .utf8))
        wait(for: [loginExpectation!], timeout: 5)
        XCTAssertTrue(results == Constant.INVALID_ACCESS_TOKEN, "iss is missing")


        //if expiry is missing
        loginExpectation = XCTestExpectation(description: "")
        jwtToken = "<sample jwt token>"
        
        endpoint?.loginWithAccessToken(jwtToken, deviceToken: "sdf".data(using: .utf8))
        wait(for: [loginExpectation!], timeout: 5)
        XCTAssertTrue(results == Constant.INVALID_ACCESS_TOKEN, "expiry is missing")

        //if nbf is missing
        loginExpectation = XCTestExpectation(description: "")
        jwtToken = "<sample jwt token>"
        //when the user is already registered
        endpoint?.loginWithAccessToken(jwtToken, deviceToken: "sdf".data(using: .utf8))
        wait(for: [loginExpectation!], timeout: 5)
        XCTAssertTrue(results == Constant.INVALID_ACCESS_TOKEN, "nbf is missing")
    }
    
    func testPlivoEndpoint_LoginWithJWTCase5_LoginShouldAllowCall() throws {
        //if per is missing
        loginExpectation = XCTestExpectation(description: "")
        jwtParams["sub"] = "test"

        endpoint?.loginWithAccessTokenGenerator(jwtDelegate: self)
        
        wait(for: [loginExpectation!], timeout: 10)
        XCTAssertTrue(results == "Login Success", "User logged in, per is missing")
    }

    //Failure case: outgoing/incoming permission not given
    func testPlivoEndpoint_LoginWithJWTCase6_LoginShouldRetrictCall() throws {
        //when the outgoing_allow is set to false explicitly
        loginExpectation = XCTestExpectation(description: "")
        permissionExpectation = XCTestExpectation(description: "")
        jwtParams["sub"] = "test"
        jwtParams["per"] = true
        jwtParams["outgoing_allow"] = false
        jwtParams["incoming_allow"] = false

        endpoint?.loginWithAccessTokenGenerator(jwtDelegate: self)
        
        wait(for: [loginExpectation!], timeout: 5)


        endpoint?.createOutgoingCall()
        wait(for: [permissionExpectation!], timeout: 5)

        XCTAssertTrue(results == Constant.INVALID_ACCESS_TOKEN_GRANTS, "outgoing_allow is false")

        //when the incoming_allow is set to false explicilty
        permissionExpectation = XCTestExpectation(description: "")

        endpoint?.relayVoipPushNotification([:])
        wait(for: [permissionExpectation!], timeout: 5)

        XCTAssertTrue(results == Constant.INVALID_ACCESS_TOKEN_GRANTS, "incoming_allow is false")
        
    }
    
    //Failure case: when the incoming and outgoing permission is not passed in the token itself
    func testPlivoEndpoint_LoginWithJWTCase7_LoginShouldRetrictCall() throws {
        //when the incoming and outgoing permission is not passed in the token itself
        loginExpectation = XCTestExpectation(description: "")
        permissionExpectation = XCTestExpectation(description: "")
        jwtParams["sub"] = "test"
        endpoint?.loginWithAccessTokenGenerator(jwtDelegate: self)
        
        wait(for: [loginExpectation!], timeout: 10)

        
        endpoint?.createOutgoingCall()
        wait(for: [permissionExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.INVALID_ACCESS_TOKEN_GRANTS, "outgoing_allow is set to false by default")

        permissionExpectation = XCTestExpectation(description: "")
        endpoint?.createOutgoingCall()
        wait(for: [permissionExpectation!], timeout: 10)
        XCTAssertTrue(results == Constant.INVALID_ACCESS_TOKEN_GRANTS, "incoming_allow is set to false by default")
    }
    
    //Failure case: //if sub is missing
    func testPlivoEndpoint_LoginWithJWTCase8_LoginShouldRetrictCall() throws {
        loginExpectation = XCTestExpectation(description: "")
        endpoint?.loginWithAccessTokenGenerator(jwtDelegate: self)
        wait(for: [loginExpectation!], timeout: 5)

        XCTAssertTrue(StatsConfig.username!.contains("puser") && StatsConfig.username!.split(separator: "_")[0].hasSuffix("jt"))
        XCTAssertTrue(results == "Login Success", "sub is missing")
    }
}

extension PlivoEndPointRegistrationTests: JWTDelegate {
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
        
        
//           let parameterDictionary = ["username" : "Test", "password" : "123456"]
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
                       var dataAsString:String = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as! String

                       let token: JWTDecoder = try JSONDecoder().decode(JWTDecoder.self, from: data)
                       self.endpoint?.loginWithAccessToken(token.token)
                       
                   } catch let decoderError {
                       print(decoderError)
                   }
               }
              
           }.resume()
    }
}
    
struct JWTDecoder: Codable {
    var api_id: String
    var token: String
}
