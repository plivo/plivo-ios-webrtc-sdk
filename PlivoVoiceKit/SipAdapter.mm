
#import "SipAdapter.h"

#include "SipControllerCore.h"

using namespace rtcsip;

class SipControllerCoreWrapper : public SipRegistrationHandler, public SipCallHandler, public SipLogHandler, public SipErrorHandler, public SipSDPHandler, public SipCallInfoHandler, public SipCallStateHandler
{
public:
    SipControllerCoreWrapper(SipControllerCore *controller);
    ~SipControllerCoreWrapper();
  
    void registerRegistrationHandler(void (^handler)(RegistrationEvent, NSString*));
    void registerCallHandler(void (^handler)(CallEvent, NSString*));
    void registerLogHandler(void (^handler)(NSString*));
    void sipSDPHandler(void (^handler)(NSString*));
    void sipCallInfo(void (^handler)(NSString*));
    void sipCallState(void (^handler)(NSString*, int));
    
    void registerErrorHandler(void (^handler)(ErrorType, NSString*));
    void registerUser(std::string username, std::string password);
    void registerUser(std::string username, std::string password, std::string token);
    void registerUser(std::string username, std::string password, std::string token, std::string certid);
    void registerUser(std::string username, std::string password, std::string token, std::string certid, std::string proxy, std::map<std::string,std::string> headers, bool isJwt);
    void registerTimeOut(int time);
    void unregisterUser(std::map<std::string,std::string> headers);
    void reject();
    void networkChange(std::map<std::string,std::string> headers);
    void ringing();
    void createSession(std::string remoteUser, std::string localSdp, std::map<std::string,std::string> headers);
    void acceptSession(std::string localSdp);
    void terminateSession();
    void resetStack();
    NSString* getPublicIp();
  
    void onIceCandidate(std::string &sdp, std::string &mid);
    void onIceGatheringFinished();
    
    void setDnsServer(std::string dns);
    void setProxyServer(std::string proxy);
    
    virtual void handleRegistration(SipRegistrationEvent sipEvent, std::string user);

    virtual void handleCall(SipCallEvent event, std::string user);
    
    virtual void handleLog(std::string log);
    
    virtual void handleSDP(std::string sdp);
    
    virtual void handleCallInfo(std::string callId);
    
    virtual void handleCallState(std::string reason, int statuscode);
  
    virtual void handleError(SipErrorType type, std::string error);
  
private:
    void (^m_registrationHandler)(RegistrationEvent, NSString*);
    void (^m_callHandler)(CallEvent, NSString*);
    void (^m_logHandler)(NSString*);
    void (^m_sdpHandler)(NSString*);
    void (^m_callInfoHandler)(NSString*);
    void (^m_callStateHandler)(NSString*, int);
    void (^m_errorHandler)(ErrorType, NSString*);
    SipControllerCore *m_sipControllerCore;
};

SipControllerCoreWrapper::SipControllerCoreWrapper(SipControllerCore *controller) :
    m_sipControllerCore(controller)
{
    m_sipControllerCore->registerRegistrationHandler(this);
    m_sipControllerCore->registerCallHandler(this);
    m_sipControllerCore->sipSDPHandler(this);
    m_sipControllerCore->sipCallInfoHandler(this);
    m_sipControllerCore->sipCallStateHandler(this);
    m_sipControllerCore->registerLogHandler(this);
    m_sipControllerCore->registerErrorHandler(this);
}

SipControllerCoreWrapper::~SipControllerCoreWrapper()
{
  
}

void SipControllerCoreWrapper::onIceCandidate(std::string &sdp, std::string &mid){
    m_sipControllerCore->onIceCandidate(sdp, mid);
}

void SipControllerCoreWrapper::onIceGatheringFinished(){
    m_sipControllerCore->onIceGatheringFinished();
}

void SipControllerCoreWrapper::registerRegistrationHandler(void (^handler)(RegistrationEvent, NSString*))
{
    m_registrationHandler = handler;
}

void SipControllerCoreWrapper::registerCallHandler(void (^handler)(CallEvent, NSString*))
{
    m_callHandler = handler;
}

void SipControllerCoreWrapper::registerLogHandler(void (^handler)(NSString*))
{
    m_logHandler = handler;
}

void SipControllerCoreWrapper::sipSDPHandler(void (^handler)(NSString*))
{
    m_sdpHandler = handler;
}

void SipControllerCoreWrapper::sipCallInfo(void (^handler)(NSString*))
{
    m_callInfoHandler = handler;
}

void SipControllerCoreWrapper::sipCallState(void (^handler)(NSString*, int))
{
    m_callStateHandler = handler;
}

void SipControllerCoreWrapper::registerErrorHandler(void (^handler)(ErrorType, NSString*))
{
    m_errorHandler = handler;
}

void SipControllerCoreWrapper::registerUser(std::string username, std::string password)
{
    m_sipControllerCore->registerUser(username, password);
}

void SipControllerCoreWrapper::registerUser(std::string username, std::string password, std::string token)
{
    m_sipControllerCore->registerUser(username, password, token);
}

void SipControllerCoreWrapper::registerUser(std::string username, std::string password, std::string token, std::string certid)
{
    m_sipControllerCore->registerUser(username, password, token, certid);
}

void SipControllerCoreWrapper::registerUser(std::string username, std::string password, std::string token, std::string certid, std::string proxy, std::map<std::string,std::string> headers, bool isJwt)
{
    m_sipControllerCore->registerUser(username, password, token, certid, proxy, headers, isJwt);
}

void SipControllerCoreWrapper::registerTimeOut(int time)
{
    m_sipControllerCore->registerTimeOut(time);
}


void SipControllerCoreWrapper::unregisterUser(std::map<std::string,std::string> headers)
{
    m_sipControllerCore->unregisterUser(headers);
}

void SipControllerCoreWrapper::createSession(std::string remoteUser, std::string localSdp, std::map<std::string,std::string> headers)
{
    m_sipControllerCore->createSession(remoteUser, localSdp, headers);
}

void SipControllerCoreWrapper::acceptSession(std::string localSdp)
{
    m_sipControllerCore->acceptSession(localSdp);
}

void SipControllerCoreWrapper::reject()
{
    m_sipControllerCore->reject();
}

void SipControllerCoreWrapper::resetStack()
{
    m_sipControllerCore->resetStack();
}

void SipControllerCoreWrapper::networkChange(std::map<std::string,std::string> headers){
    m_sipControllerCore->networkChange(headers);
}

NSString* SipControllerCoreWrapper::getPublicIp()
{
    NSString *stringinObjC = [NSString stringWithCString:m_sipControllerCore->getPublicIp().c_str()
                                    encoding:[NSString defaultCStringEncoding]];
    return stringinObjC;
}

void SipControllerCoreWrapper::ringing()
{
    m_sipControllerCore->ringing();
}

void SipControllerCoreWrapper::terminateSession()
{
    m_sipControllerCore->terminateSession();
}

void SipControllerCoreWrapper::handleRegistration(SipRegistrationEvent sipEvent, std::string user)
{
    RegistrationEvent event;
    if (sipEvent == SipRegistrationEvent::Registered)
        event = RegistrationEvent::Registered;
    else if (sipEvent == SipRegistrationEvent::NotRegistered)
        event = RegistrationEvent::NotRegistered;
    else if (sipEvent == SipRegistrationEvent::NotRegisteredJWT)
        event = RegistrationEvent::NotRegisteredJWT;
    else
        return;
    
    if (m_registrationHandler)
        m_registrationHandler(event, [NSString stringWithUTF8String:user.c_str()]);
 
}

void SipControllerCoreWrapper::handleCall(SipCallEvent sipEvent, std::string user)
{
    CallEvent event;
    if (sipEvent == SipCallEvent::IncomingCall)
        event = CallEvent::IncomingCall;
    else if (sipEvent == SipCallEvent::TerminateCall)
        event = CallEvent::TerminateCall;
    else if (sipEvent == SipCallEvent::CallAccepted)
        event = CallEvent::CallAccepted;
    else
        return;
  
    if (m_callHandler)
        m_callHandler(event, [NSString stringWithUTF8String:user.c_str()]);
}

void SipControllerCoreWrapper::handleLog(std::string log)
{
    if (m_logHandler)
        m_logHandler([NSString stringWithUTF8String:log.c_str()]);
}

void SipControllerCoreWrapper::handleSDP(std::string sdp)
{
    if (m_sdpHandler)
        m_sdpHandler([NSString stringWithUTF8String:sdp.c_str()]);
}

void SipControllerCoreWrapper::handleCallInfo(std::string callId)
{
    if (m_callInfoHandler)
        m_callInfoHandler([NSString stringWithUTF8String:callId.c_str()]);
}

void SipControllerCoreWrapper::handleCallState(std::string state, int statusCode)
{
    if (m_callStateHandler)
        m_callStateHandler([NSString stringWithUTF8String:state.c_str()],statusCode);
}

void SipControllerCoreWrapper::handleError(SipErrorType sipType, std::string error)
{
    ErrorType type;
    if (sipType == SipErrorType::WebRtcError)
        type = ErrorType::WebRtcError;
    else if (sipType == SipErrorType::SipConnectionError)
        type = ErrorType::SipStackError;
    else if (sipType == SipErrorType::SipSessionError)
        type = ErrorType::SipStackError;
    else
        return;
  
    if (m_errorHandler)
        m_errorHandler(type, [NSString stringWithUTF8String:error.c_str()]);
}








#import <PlivoVoiceKit/PlivoVoiceKit-Swift.h>
@class Environment;

@interface SipAdapter ()

@property(nonatomic, assign) SipControllerCoreWrapper *sipControllerCoreWrapper;
@property(nonatomic, assign) SipControllerCore *sipControllerCore;

@end

@implementation SipAdapter

@synthesize sipControllerCore = _sipControllerCore;
@synthesize sipControllerCoreWrapper = _sipControllerCoreWrapper;


- (id)init {
    if (self = [super init]) {
        rtcsip::SipServerSettings sipServerSettings;
        std::string domainString([[Environment sipDomain] UTF8String]);
        std::string proxyString([[Environment proxy] UTF8String]);
        std::string fallbackProxy([[Environment FALLBACK_PROXY] UTF8String]);
        std::string userAgent([[Environment userAgent] UTF8String]);

        sipServerSettings.domain = domainString;
        sipServerSettings.proxyServer = proxyString;
        sipServerSettings.fallbackProxyServer = fallbackProxy;
        sipServerSettings.userAgent = userAgent;
        _sipControllerCore = new rtcsip::SipControllerCore(sipServerSettings);
        _sipControllerCoreWrapper = new SipControllerCoreWrapper(_sipControllerCore);
    }
    NSLog(@"init : SipAdapter");
    return self;
}

- (void)dealloc {
    NSLog(@"deinit : SipAdapter");
    delete(_sipControllerCore);
    delete(_sipControllerCoreWrapper);
}

//UT: Write test case for this method with assert that all four attributes are validated in the desired format
- (void)registerUserWithUsername:(NSString *)username andPassword:(NSString *)password{
    //Note: Considering that all the variables are pre-validated in caller class
    std::string usernameString([username UTF8String]);
    std::string passwordString([password UTF8String]);
    _sipControllerCoreWrapper->registerUser(usernameString, passwordString);
}

- (void)registerUserWithUsername:(NSString *)username andPassword:(NSString *)password andToken:(NSString *)token{
    //Note: Considering that all the variables are pre-validated in caller class
    std::string usernameString([username UTF8String]);
    std::string passwordString([password UTF8String]);
    std::string deviceToken([token UTF8String]);
    _sipControllerCoreWrapper->registerUser(usernameString, passwordString, deviceToken);
}

- (void)registerUserWithUsername:(NSString *)username andPassword:(NSString *)password andToken:(NSString *)token andCertificateId:(NSString *)certid{
    //Note: Considering that all the variables are pre-validated in caller class
    std::string usernameString([username UTF8String]);
    std::string passwordString([password UTF8String]);
    std::string deviceToken([token UTF8String]);
    std::string certificateId([certid UTF8String]);
    _sipControllerCoreWrapper->registerUser(usernameString, passwordString, deviceToken, certificateId);
}

- (void)registerUserWithUsername:(NSString *)username andPassword:(NSString *)password andToken:(NSString *)token andCertificateId:(NSString *)certid andproxy:(NSString *)proxy andHeaders:(NSDictionary *)headers isJwt:(bool)isJwt{
    std::string usernameString([username UTF8String]);
    std::string passwordString([password UTF8String]);
    std::string deviceToken([token UTF8String]);
    std::string certificateId([certid UTF8String]);
    std::string proxyAddress([proxy UTF8String]);
    
    std::map<std::string,std::string> h;
    for (NSString *key in headers) {
        h[[key UTF8String]] = [[headers objectForKey:key] UTF8String];
    }
    
    _sipControllerCoreWrapper->registerUser(usernameString, passwordString, deviceToken, certificateId, proxyAddress, h, isJwt);
}

- (void)setRegisterTimeout:(NSNumber *)time{
    int timeout([time intValue]);
    _sipControllerCoreWrapper->registerTimeOut(timeout);
}

- (void)registerErrorHandler:(void (^)(ErrorType, NSString*))handler {
    _sipControllerCoreWrapper->registerErrorHandler(handler);
}

- (void)registerRegistrationHandler:(void (^)(RegistrationEvent, NSString*))handler {
    _sipControllerCoreWrapper->registerRegistrationHandler(handler);
}

- (void)registerCallHandler:(void (^)(CallEvent, NSString*))handler {
    _sipControllerCoreWrapper->registerCallHandler(handler);
}

- (void)registerLogHandler:(void (^)(NSString*))handler {
    _sipControllerCoreWrapper->registerLogHandler(handler);
}

- (void)unregisterUser:(NSDictionary *)headers {
    std::map<std::string,std::string> h;
    for (NSString *key in headers) {
        h[[key UTF8String]] = [[headers objectForKey:key] UTF8String];
    }
    _sipControllerCoreWrapper->unregisterUser(h);
}

- (void)makeCallTo:(NSString *)sipUri andLocalSdp:(NSString *)localSdp{
    std::map<std::string,std::string> h;
    _sipControllerCoreWrapper->createSession([sipUri UTF8String], [localSdp UTF8String], h);
}

- (void)makeCallTo:(NSString *)sipUri andLocalSdp:(NSString *)localSdp andHeaders:(NSDictionary *)headers{
    std::map<std::string,std::string> h;
    for (NSString *key in headers) {
        h[[key UTF8String]] = [[headers objectForKey:key] UTF8String];
    }
    
    _sipControllerCoreWrapper->createSession([sipUri UTF8String], [localSdp UTF8String], h);
}

- (void)answer: (NSString *)localSdp {
    _sipControllerCoreWrapper->acceptSession([localSdp UTF8String]);
}

- (void)rejectCall{
    _sipControllerCoreWrapper->reject();
}

- (void)resetStack{
    _sipControllerCoreWrapper->resetStack();
}

- (void)networkChange: (NSDictionary *) headers{
    std::map<std::string,std::string> h;
    for (NSString *key in headers) {
        h[[key UTF8String]] = [[headers objectForKey:key] UTF8String];
    }
    _sipControllerCoreWrapper->networkChange(h);
}

- (void)sendRinging{
    _sipControllerCoreWrapper->ringing();
}

- (void)endCallAndDestroyLocalStream {
    _sipControllerCoreWrapper->terminateSession();
}

- (void)sipSDPHandler:(void (^)(NSString*))handler {
    _sipControllerCoreWrapper->sipSDPHandler(handler);
}

- (void)sipCallInfoHandler:(void (^)(NSString*))handler {
    _sipControllerCoreWrapper->sipCallInfo(handler);
}

- (void) onIceCandidate: (NSString *)sdp andMid:(NSString *)mid{
    std::string sdpString([sdp UTF8String]);
    std::string midString([mid UTF8String]);
    _sipControllerCoreWrapper->onIceCandidate(sdpString, midString);
}

- (void) onIceGatheringFinished{
    _sipControllerCoreWrapper->onIceGatheringFinished();
}

- (void) hangupSession{
    _sipControllerCoreWrapper->terminateSession();
}

- (void)sipCallStateHandler:(void (^)(NSString*, int))handler{
    _sipControllerCoreWrapper->sipCallState(handler);
}

- (NSString*) getPublicIp{
    return _sipControllerCoreWrapper->getPublicIp();
}

@end
