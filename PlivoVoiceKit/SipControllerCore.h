

#ifndef SIPCONTROLLERCORE_H__
#define SIPCONTROLLERCORE_H__

#import "SipStack.hxx"
#import "DialogUsageManager.hxx"
#import "MasterProfile.hxx"
#import "ClientAuthManager.hxx"
#import "KeepAliveManager.hxx"
#import "ClientRegistration.hxx"
#import "RegistrationHandler.hxx"
#import "ClientInviteSession.hxx"
#import "InviteSessionHandler.hxx"
#import "ServerInviteSession.hxx"
#import "EventStackThread.hxx"
#import "SdpContents.hxx"
#import "SipMessage.hxx"
#include "DumShutdownHandler.hxx"
#import "Logger.hxx"
#import "Security.hxx"
#import "CertManager.h"
#import "ExtensionHeader.hxx"
#import "DnsUtil.hxx"

#include <mutex>
#include <thread>
#include <map>

#define RESIPROCATE_SUBSYSTEM resip::Subsystem::APP

using namespace resip;

namespace rtcsip
{
    enum SipRegistrationEvent
    {
        Registered,
        NotRegistered
    };
    
    enum SipCallEvent
    {
        IncomingCall,
        TerminateCall,
        CallAccepted
    };
  
    enum SipErrorType
    {
        WebRtcError,
        SipConnectionError,
        SipSessionError
    };
  
    struct SipServerSettings
    {
      std::string domain;
      std::string dnsServer;
      std::string proxyServer;
    };
    
    class SipRegistrationHandler
    {
    public:
        virtual void handleRegistration(SipRegistrationEvent sipEvent, std::string user) = 0;
    };

    class SipCallHandler
    {
    public:
        virtual void handleCall(SipCallEvent sipEvent, std::string user) = 0;
    };
  
    class SipLogHandler
    {
    public:
        virtual void handleLog(std::string log) = 0;
    };

    class SipSDPHandler
    {
    public:
        virtual void handleSDP(std::string sdp) = 0;
    };
  
    class SipCallInfoHandler
    {
    public:
        virtual void handleCallInfo(std::string callInfo) = 0;
    };

    class SipErrorHandler
    {
    public:
        virtual void handleError(SipErrorType sipType, std::string error) = 0;
    };

    class SipCallStateHandler
    {
    public:
        virtual void handleCallState(std::string state, int statusCode) = 0;
    };

    class SipControllerCore : public ClientRegistrationHandler, public InviteSessionHandler, public ExternalLogger, public DumShutdownHandler{

    public:
        struct IceCandidate
        {
            std::string mid;
            std::string candidate;
        };
      
        SipControllerCore(SipServerSettings serverSettings);
        ~SipControllerCore();
    
        void receive();
        void registerRegistrationHandler(SipRegistrationHandler* handler);
        void registerCallHandler(SipCallHandler* handler);
        void registerLogHandler(SipLogHandler* handler);
        void sipSDPHandler(SipSDPHandler* handler);
        void sipCallStateHandler(SipCallStateHandler* handler);
        void sipCallInfoHandler(SipCallInfoHandler* handler);
        void registerErrorHandler(SipErrorHandler* handler);
        std::string createUri(const std::string &username);
        
        void registerUser(std::string username, std::string password);
        void registerUser(std::string username, std::string password, std::string token);
        void addapnsInContact(const std::string &certid, std::string &contactAddress, const std::string &token);
        
        void registerUser(std::string username, std::string password, std::string token, std::string certid);
        void registerUser(std::string username, std::string password, std::string token, std::string certid, std::string proxy, std::map<std::string,std::string> headers);
        void registerTimeOut(int time);
        void unregisterUser();
        void createSession(std::string remoteUser, std::string localSdp, std::map<std::string,std::string> headers);
        void acceptSession(std::string localSdp);
        void reject();
        void rejectOtherCall();
        void networkChange();
        void handleLog(std::string value);
        std::string getCallId(const SipMessage& msg);
        bool isValidUserAgent(const SipMessage& msg);
        int getStatusCode(const SipMessage& msg);
        void ringing();
        void removeAllActive();
        void terminateSession();
        void resetStack();
    
        virtual void onSuccess(ClientRegistrationHandle, const SipMessage& response);
        virtual void onRemoved(ClientRegistrationHandle, const SipMessage& response);
        virtual int onRequestRetry(ClientRegistrationHandle, int retrySeconds, const SipMessage& response);
        virtual void onFailure(ClientRegistrationHandle, const SipMessage& response);
        virtual void onFlowTerminated(ClientRegistrationHandle);

        virtual void onNewSession(ClientInviteSessionHandle, InviteSession::OfferAnswerType oat, const SipMessage& msg);
        virtual void onNewSession(ServerInviteSessionHandle, InviteSession::OfferAnswerType oat, const SipMessage& msg);
        virtual void onFailure(ClientInviteSessionHandle, const SipMessage& msg);
        virtual void onEarlyMedia(ClientInviteSessionHandle, const SipMessage&, const SdpContents&);
        virtual void onProvisional(ClientInviteSessionHandle, const SipMessage&);
        virtual void onConnected(ClientInviteSessionHandle, const SipMessage& msg);
        virtual void onConnected(InviteSessionHandle, const SipMessage& msg);
        virtual void onTerminated(InviteSessionHandle, InviteSessionHandler::TerminatedReason reason, const SipMessage* related=0);
        virtual void onForkDestroyed(ClientInviteSessionHandle);
        virtual void onRedirected(ClientInviteSessionHandle, const SipMessage& msg);
        virtual void onStaleCallTimeout(ClientInviteSessionHandle);
        virtual void onAnswer(InviteSessionHandle, const SipMessage& msg, const SdpContents&);
        virtual void onOffer(InviteSessionHandle, const SipMessage& msg, const SdpContents&);
        virtual void onOfferRequired(InviteSessionHandle, const SipMessage& msg);
        virtual void onOfferRejected(InviteSessionHandle, const SipMessage* msg);
        virtual void onInfo(InviteSessionHandle, const SipMessage& msg);
        virtual void onInfoSuccess(InviteSessionHandle, const SipMessage& msg);
        virtual void onInfoFailure(InviteSessionHandle, const SipMessage& msg);
        virtual void onMessage(InviteSessionHandle, const SipMessage& msg);
        virtual void onMessageSuccess(InviteSessionHandle, const SipMessage& msg);
        virtual void onMessageFailure(InviteSessionHandle, const SipMessage& msg);
        virtual void onRefer(InviteSessionHandle, ServerSubscriptionHandle, const SipMessage& msg);
        virtual void onReferNoSub(InviteSessionHandle, const SipMessage& msg);
        virtual void onReferRejected(InviteSessionHandle, const SipMessage& msg);
        virtual void onReferAccepted(InviteSessionHandle, ClientSubscriptionHandle, const SipMessage& msg);
        virtual void onDumCanBeDeleted();
        virtual bool operator()(Log::Level level,
                                const Subsystem& subsystem,
                                const Data& appName,
                                const char* file,
                                int line,
                                const Data& message,
                                const Data& messageWithHeaders);
    
        void onIceCandidate(std::string &sdp, std::string &mid);
        void onIceGatheringFinished();

    private:
        void setupTransport(std::string address, std::string contact_url);
        void setupCredential(std::string username, std::string password);
        void createMasterProfile();
        void sendSdpAnswer();
        void sendSdpOffer(std::map<std::string,std::string> headers);
        Tuple processIpAndPort(const SipMessage& message);
        std::string processCallInfo(const SipMessage& message);
        
    private:
        std::string m_domain;
        std::string m_primary_domain = "client.plivo.com";
        std::string m_fallback_domain = "client-fb.plivo.com";
        bool m_run;
        bool m_receiveClosed;
        std::string m_localSdp;
        std::string m_remoteSdp;
        std::vector<IceCandidate> m_localCandidates;
        bool m_inCall;
        bool m_isRunning;
        bool m_isCaller;
        bool m_remoteSdpSet;
        bool m_localCandidatesCollected;
        bool m_inInBoundAccepted;
        bool m_connection_broken = false;
        std::thread *m_receiver;
        std::mutex m_receiveMutex;
        std::condition_variable m_receiveCondition;
        std::mutex m_controllerMutex;
        std::mutex m_logMutex;
        std::mutex m_sdpMutex;
        SipRegistrationHandler *m_registrationHandler;
        SipCallHandler *m_callHandler;
        SipLogHandler *m_logHandler;
        SipSDPHandler *m_sdpHandler;
        SipCallStateHandler *m_callStateHandler;
        SipCallInfoHandler *m_callInfoHandler;
        SipErrorHandler *m_errorHandler;
        char m_logBuffer[65536];
#ifdef ANDROID
        AndroidLogger m_androidLog;
#endif

        SharedPtr<SipStack> m_stack;
        DnsStub::NameserverList m_dnsServers;
        EventStackThread* m_stackThread;
        DialogUsageManager* m_userAgent;
        FdPollGrp* m_pollGrp;
        EventThreadInterruptor* m_interruptor;
        NameAddr m_clientAddress;
        Uri m_outboundProxy;
        SharedPtr<MasterProfile> m_masterProfile;
        std::auto_ptr<ClientAuthManager> m_clientAuth;
        ClientInviteSession* m_clientInviteSession;
        ServerInviteSession* m_serverInviteSession;
        ServerInviteSession* m_otherServerInviteSession;
        NameAddr registeredContact;
        int tls_key;
        int tcp_key;
        int udp_key;
        
        std::map<std::string,std::string> m_headers;
        std::string m_uri;
        std::string m_current_callid;
        std::string m_app_id;
        std::string m_cert_id;
        std::string m_username;
        std::string m_password;
        std::string m_remoteUri;
        std::string m_dnsServer;
        std::string m_proxyServer;
        std::string m_public_ip_port;
        bool isProxyRegister;
        bool isUACRejected;
        int m_reg_timeout = 0;
        bool isSecondaryUAC;
        
        typedef enum
        {
            Dialing,
            Ringing,
            Connected,
            Done
        } DialProgress;
        
        DialProgress mProgress;
  };

}
#endif






//RESIPROCATE CHEAT

//
//
//
//NameAddr route;
//              route.uri().scheme() = "sip";
//              route.uri().user() = "proxy";
//              route.uri().host() = SipStack::getHostname();
//              route.uri().port() = 5070;
//              route.uri().param(p_transport) = Tuple::toData(mTransport);
//              rRoutes.push_front(route);
//
//              NameAddr& frontRRoute = rRoutes.front();
//              ErrLog ( << "rRoute: " << frontRRoute.uri().toString());
