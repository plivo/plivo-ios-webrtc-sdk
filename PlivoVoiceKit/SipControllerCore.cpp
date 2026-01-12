
#include "SipControllerCore.h"

#ifdef ANDROID
#include <android/log.h>
#endif

namespace rtcsip {


SipControllerCore::SipControllerCore(SipServerSettings serverSettings) :
m_run(false),
m_receiveClosed(false),
m_inCall(false),
m_isCaller(false),
m_remoteSdpSet(false),
m_localCandidatesCollected(false),
m_receiver(NULL),
m_registrationHandler(NULL),
m_callHandler(NULL),
m_logHandler(NULL),
m_sdpHandler(NULL),
m_callStateHandler(NULL),
m_errorHandler(NULL)
{
    m_domain = serverSettings.domain;
    m_dnsServer = serverSettings.dnsServer;
    m_proxyServer = serverSettings.proxyServer;
    m_fallbackProxyServer = serverSettings.fallbackProxyServer;
    m_userAgentName = serverSettings.userAgent;
}

SipControllerCore::~SipControllerCore()
{
    if (m_receiver)
        m_receiver->detach();
    if (m_stack){
        m_stack->shutdown();
    }
//    if (m_stackThread){
//        m_stackThread->shutdown();
//    }
    handleLog(" deinit() ");
}

void SipControllerCore::receive(){
    bool run = true;
    while (run){
        if (m_userAgent != NULL){
            m_userAgent->process();
            m_receiveMutex.lock();
            run = m_run;
            sleepMs(100);
            m_receiveMutex.unlock();
        }
    }
    m_receiveMutex.lock();
    m_receiveClosed = true;
    m_receiveMutex.unlock();
    m_receiveCondition.notify_one();
}



/*
 *
 MARK: Handler setup
 *
 */
void SipControllerCore::registerRegistrationHandler(SipRegistrationHandler* handler){
    std::lock_guard<std::mutex> lock(m_controllerMutex);
    m_registrationHandler = handler;
}

void SipControllerCore::registerCallHandler(SipCallHandler* handler){
    std::lock_guard<std::mutex> lock(m_controllerMutex);
    m_callHandler = handler;
}

void SipControllerCore::registerLogHandler(SipLogHandler* handler){
    std::lock_guard<std::mutex> lock(m_controllerMutex);
    m_logHandler = handler;
}

void SipControllerCore::sipSDPHandler(SipSDPHandler* handler){
    std::lock_guard<std::mutex> lock(m_controllerMutex);
    m_sdpHandler = handler;
}

void SipControllerCore::sipCallInfoHandler(SipCallInfoHandler* handler){
    std::lock_guard<std::mutex> lock(m_controllerMutex);
    m_callInfoHandler = handler;
}

void SipControllerCore::registerErrorHandler(SipErrorHandler* handler){
    std::lock_guard<std::mutex> lock(m_controllerMutex);
    m_errorHandler = handler;
}

void SipControllerCore::sipCallStateHandler(SipCallStateHandler* handler){
    std::lock_guard<std::mutex> lock(m_controllerMutex);
    m_callStateHandler = handler;
}




/*
 *
 MARK: Custom methods
 *
 */
std::string SipControllerCore::processCallInfo(const SipMessage& message){
    std::string callInfo = "";
    callInfo = callInfo + "type:" + "outgoing";
    
    if (m_current_callid.size() != 0){
        callInfo = callInfo + "," + "call_id:" + m_current_callid;
    }
    
    for (auto &&i :message.getRawUnknownHeaders()){
        std::string value = message.header(ExtensionHeader(i.first)).front().value().c_str();
        callInfo = callInfo + "," + i.first.c_str() + ":" + value;
    }
    
    resip::H_From fromHT;
    H_From::Type from = message.header(fromHT);
    const char* fromC = from.uri().user().c_str();
    
    callInfo = callInfo + "," + "from:" + fromC;
    
    resip::H_To toHT;
    H_From::Type to = message.header(toHT);
    const char* toC = to.uri().user().c_str();
    
    callInfo = callInfo + "," + "to:" + toC;
    return callInfo;
}

Tuple SipControllerCore::processIpAndPort(const SipMessage &message){
    handleLog(" processing ip and port processIpAndPort()");
    if(message.exists(h_Vias) == false){
        return Tuple();
    }
    Vias::const_iterator it = message.header(h_Vias).end();
    while(true)
    {
        it--;
        if(it->exists(p_received))
        {
            // Check IP from received parameter
            Tuple address(it->param(p_received), 0, UNKNOWN_TRANSPORT);
            if(!address.isPrivateAddress())
            {
                address.setPort(it->exists(p_rport) ? it->param(p_rport).port() : it->sentPort());
                address.setType(Tuple::toTransport(it->transport()));
                if (address.getType() != UNKNOWN_TRANSPORT) {
                    m_public_ip = Tuple::inet_ntop(address).c_str();
                }
                return address;
            }
        }
        // Check IP from Via sentHost
        if(DnsUtil::isIpV4Address(it->sentHost())  // Ensure the via host is an IP address (note: web-rtc uses hostnames here instead)
            #ifdef USE_IPV6
                || DnsUtil::isIpV6Address(it->sentHost())
            #endif
           )
        {
            Tuple address(it->sentHost(), 0, UNKNOWN_TRANSPORT);
            if(address.isPrivateAddress())
            {
                address.setPort(it->exists(p_rport) ? it->param(p_rport).port() : it->sentPort());
                address.setType(Tuple::toTransport(it->transport()));
                return address;
            }
        }
        if(it == message.header(h_Vias).begin()) break;
    }
    return Tuple();
}

std::string SipControllerCore::getCallId(const SipMessage& msg){
    handleLog(" getCallId()");
    std::string result;
    if (msg.exists(h_CallId)){
        result = msg.header(h_CallId).value().c_str();
    }
    return result;
}

bool SipControllerCore::isValidUserAgent(const SipMessage& msg){
    handleLog(" isValidUserAgent()");
    bool result = false;
    if(msg.exists(h_UserAgent)){
        std::string user_agent = msg.header(h_UserAgent).value().c_str();
        for(char &ch : user_agent){
            ch = std::tolower(ch);
        }
        if (user_agent.find("plivo") != std::string::npos) {
            result = true;
        }
    }
    return  result;
}

int SipControllerCore::getStatusCode(const SipMessage& msg){
    handleLog(" getStatusCode()");
    int result;
    result = msg.header(h_StatusLine).responseCode();
    return result;
}

void SipControllerCore::handleLog(std::string value) {
    
    if ((value.find("Failed to find connection") != std::string::npos) && ((!m_outboundProxy.host().empty() && value.find("targetDomain=" + m_proxyServer) != std::string::npos) || value.find("targetDomain="+ m_domain) != std::string::npos)) {
        refresh_targets = true;
        handleLog("PLIVO DEBUG FLAG found connection termination from server | Reregister in ideal state");
        moveToFallback();
//        reRegister();
       
    }
    
    SipLogHandler *logHandler;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        logHandler = m_logHandler;
    }
    logHandler->handleLog("SipControllerCore:: "+value);
}

void SipControllerCore::reRegister() {
    handleLog("SipControllerCore :: reRegister");
    if (m_cert_id.empty() == false && m_cert_id != "NA" && m_cert_id != "" &&
        m_app_id.empty() == false && m_app_id != "NA" && m_app_id != "") {
        if (m_isJwt) {
            registerUser(m_username, "NA", m_app_id, m_cert_id, m_proxyServer, m_headers, m_isJwt);
        } else {
            registerUser(m_username, m_password, m_app_id, m_cert_id);
        }
    } else if (m_app_id.empty() == false && m_app_id != "NA" && m_app_id != "") {
        if (m_isJwt) {
            registerUser(m_username, "NA", m_app_id, "NA", m_proxyServer, m_headers, m_isJwt);
        } else {
            registerUser(m_username, m_password, m_app_id);
        }
    } else {
        if (m_isJwt) {
            registerUser(m_username, "NA", "NA", "NA", m_proxyServer, m_headers, m_isJwt);
        } else {
            registerUser(m_username, m_password);
        }
    }
}

std::string SipControllerCore::createUri(const std::string &username) {
    m_uri = username + "@" + m_domain ;
    std::string sipUri = "<sip:" + m_uri + ";transport=tls>" ;
    handleLog(" createUri() result : " + sipUri);
    return sipUri;
}

void SipControllerCore::addapnsInContact(const std::string &certid, std::string &contactAddress, const std::string &token) {
    
    if ((certid.size() == 0) && (token.size() == 0)){
        contactAddress = contactAddress + ">";
    }
    
    if (certid.size() != 0){
        contactAddress = contactAddress + ";certid=" + certid + ">";
    }
    
    if (token.size() != 0){
        std::string p = ">";
        std::string::size_type n = p.length();
        
        for (std::string::size_type i = contactAddress.find(p);
             i != std::string::npos;
             i = contactAddress.find(p))
        contactAddress.erase(i, n);
        
        contactAddress = contactAddress + ";app_id=" + token + ">";
    }
    
    handleLog(" addapnsInContact() modified contact Address : " + contactAddress);
}

/// Outgoing call
void SipControllerCore::sendSdpOffer(std::map<std::string,std::string> headers = {}){
    handleLog("SDP Offer local sdp : " + m_localSdp);
    
    //since we are sending the offer for the outgoing call. setting `isCallRinging` true
    //as the call would be in the ringing state.
    isCallRinging = true;
    
    Data txt(m_localSdp);
    HeaderFieldValue hfv(txt.data(), txt.size());
    Mime type("application", "sdp");
    SdpContents offerSdp(hfv, type);
    
    SdpContents::Session::Medium* audioMedium = NULL;
    SdpContents::Session::Medium* videoMedium = NULL;
    
    SdpContents::Session::MediumContainer& mediumContainer = offerSdp.session().media();
    
    SdpContents::Session::MediumContainer::iterator iter = mediumContainer.begin();
    while (iter != mediumContainer.end()){
        if (iter->name() == "audio")
            audioMedium = &(*iter);
        else if (iter->name() == "video")
            videoMedium = &(*iter);
        iter++;
    }
    
    std::vector<IceCandidate> localCandidates;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        localCandidates = m_localCandidates;
    }
    
    std::vector<IceCandidate>::iterator candidateIterator = localCandidates.begin();
    while (candidateIterator != localCandidates.end()){
        std::string localCandidate = candidateIterator->candidate;
        std::string midString(candidateIterator->mid);
        std::string candidateString(candidateIterator->candidate);
        Data candidateData(candidateString.c_str());
        if (audioMedium != NULL && midString.compare("0") == 0)
            audioMedium->addAttribute(Data("candidate"), candidateData.substr(10));
        else if (videoMedium != NULL && midString.compare("video") == 0)
            videoMedium->addAttribute(Data("candidate"), candidateData.substr(10));
        candidateIterator++;
    }
    
    std::string address = "sip:" + m_remoteUri + "@" + m_domain + ";transport=tls";
    SharedPtr<SipMessage> msg = m_userAgent->makeInviteSession(NameAddr(address.c_str()), m_masterProfile, &offerSdp, 0);
    
    for (auto const& [key, val] : headers){
        const Data headerName(key);
        resip::ExtensionHeader h_Tmp(headerName);
        handleLog("SDP Offer header values: " + val);
        msg->header(h_Tmp).push_back(StringCategory(val.c_str()));
    }

    m_userAgent->send(msg);
    
    m_localCandidates.clear();
    
    SipCallStateHandler *callStateHandler;
    {
        callStateHandler = m_callStateHandler;
    }
    
    callStateHandler->handleCallState("Calling", 000);
}

/// Incoming call
void SipControllerCore::sendSdpAnswer(){
    handleLog("SDP Answer Sent | Incoming call flow");

    //change the call state from ringing to answer as the user has answered the call.
    
    isCallRinging = false;
    Data txt(m_localSdp);
    
    HeaderFieldValue hfv(txt.data(), txt.size());
    Mime type("application", "sdp");
    SdpContents answerSdp(hfv, type);
    
    SdpContents::Session::Medium* audioMedium = NULL;
    SdpContents::Session::Medium* videoMedium = NULL;
    
    SdpContents::Session::MediumContainer& mediumContainer = answerSdp.session().media();
    
    SdpContents::Session::MediumContainer::iterator iter = mediumContainer.begin();
    while (iter != mediumContainer.end()){
        if (iter->name() == "audio")
            audioMedium = &(*iter);
        else if (iter->name() == "video")
            videoMedium = &(*iter);
        iter++;
    }
    
    std::vector<IceCandidate> localCandidates;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        localCandidates = m_localCandidates;
    }
    
    std::vector<IceCandidate>::iterator candidateIterator = localCandidates.begin();
    while (candidateIterator != localCandidates.end())
    {
        std::string midString(candidateIterator->mid);
        std::string candidateString(candidateIterator->candidate);
        Data candidateData(candidateString.c_str());
        if (audioMedium != NULL && midString.compare("0") == 0)
            audioMedium->addAttribute(Data("candidate"), candidateData.substr(10));
        else if (videoMedium != NULL && midString.compare("video") == 0)
            videoMedium->addAttribute(Data("candidate"), candidateData.substr(10));
        candidateIterator++;
    }
    
    // Call state handler
    SipCallStateHandler *callStateHandler;
    {
        callStateHandler = m_callStateHandler;
    }
    
    callStateHandler->handleCallState("CallAccepted", 200);
    
    m_localCandidates.clear();
    
    m_serverInviteSession->provideAnswer(answerSdp);
    m_serverInviteSession->accept();
}

void SipControllerCore::registerUser(std::string username, std::string password){
    isProxyRegister = false;
    std::string sipUri = createUri(username);
    
    handleLog("registerUser with (username/password): uri : " + sipUri);
    
    m_username = username;
    m_password = password;
    
    setupTransport(sipUri, sipUri);
}

void SipControllerCore::registerUser(std::string username, std::string password, std::string token){
    isProxyRegister = false;
    
    std::string sipUri = createUri(username);
    
    m_app_id = token;
    
    std::string contact_url = "<sip:" + m_uri + ";transport=tls;app_id=" + token + ">";
    
    handleLog("registerUser: uri with (username/password/token): " + sipUri + "contact uri : " + contact_url);
    
    m_username = username;
    m_password = password;
    
    setupTransport(sipUri, contact_url);
}

void SipControllerCore::registerUser(std::string username, std::string password, std::string token, std::string certid){
    isProxyRegister = false;
    
    std::string sipUri = createUri(username);
    
    std::string contactAddress = sipUri;
    
    m_app_id = token;
    m_cert_id = certid;
    
    addapnsInContact(certid, contactAddress, token);
    
    handleLog("registerUser: uri with (username/password/token/certid): " + sipUri + sipUri + "contact uri : " + contactAddress);
    
    m_username = username;
    m_password = password;
    
    setupTransport(sipUri, contactAddress);
}

void SipControllerCore::registerUser(std::string username, std::string password, std::string token, std::string certid, std::string proxy, std::map<std::string,std::string> headers, bool isJwt){
    
    isUACRejected = false;
    m_isJwt = isJwt;
    isProxyRegister = false;
    
    std::string sipUri = createUri(username);
    
    std::string contactAddress = sipUri;
    
    contactAddress = "<sip:" + username + "@" + m_domain + ";transport=tls>";
    
    if (proxy != "NA"){
        m_proxyServer = proxy;
    }

    m_headers = headers;
    
    if (certid != "NA"){
        m_cert_id = certid;
    }
    
    if (token != "NA"){
        m_app_id = token;
    }
    
    if (certid != "NA" && token != "NA"){
        addapnsInContact(certid, contactAddress, token);
    }else if (certid != "NA"){
        contactAddress = "<sip:" + username + "@" + m_domain + ";transport=tls;certid=" + certid + ">";
    }else if (token != "NA"){
        contactAddress = "<sip:" + username + "@" + m_domain + ";transport=tls;app_id=" + token + ">";
    }
    
    handleLog("registerUser: uri with (username/password/token/certid/proxy/headers/accessToken): " + sipUri + " proxy " + m_proxyServer + " m_app id " + m_app_id + " m_cert_id " + m_cert_id + " contact " + contactAddress);
    
    m_username = username;
    m_password = password;
    
    setupTransport(sipUri, contactAddress);
}

bool SipControllerCore::operator()(Log::Level level,
                                   const Subsystem& subsystem,
                                   const Data& appName,
                                   const char* file,
                                   int line,
                                   const Data& message,
                                   const Data& messageWithHeaders)
{
    std::string raw = message.c_str();
    if(isRegistrationInProgress && checkIfSipMessage(raw)){
        std::string dateString = getDateString();
        sipLogString = sipLogString +"["+ dateString +"]" +raw + "##";
    }
    handleLog(raw);
    return false;
}

void SipControllerCore::setupTransport(std::string address, std::string contact_url){
    if (isRegistrationInProgress == true && refresh_targets == true) {
        handleLog("Registration already in progress. Returning from here");
        return;
    }
    
    isRegistrationInProgress = true;
    handleLog("setupTransport: url: " + address + " contact " + contact_url);
    Data appname("plivo_resip.log");
    Data loglevel("STACK");

    Log::initialize("plivo_resip_log", loglevel, "", appname.c_str(), (ExternalLogger*)this);

    //Proxy Setup
    if (m_proxyServer.size() != 0){
        std::string proxyAddress = "sip:" + m_proxyServer + ";transport=tls";
        m_outboundProxy = Uri(Data(proxyAddress));
    }else{
        m_outboundProxy = Uri();
    }
    
    if (m_stack == nullptr){
        handleLog("setupTransport: setup stack | add transport");
        //DNS Setup
        Data dnsServer("8.8.8.8");
        m_dnsServers.push_back(Tuple(dnsServer, 0, UNKNOWN_TRANSPORT).toGenericIPAddress());
        
        //Certificate and Security setup
        Data caFile(root_cert);
        
        Security* security;
        security = new Security(caFile);
        
        //Note: With opensigcom do not remove these line
        //    Compression *compression = new Compression(Compression::DEFLATE);
        
        security->addCAFile(caFile);
        //    m_stack.reset(new SipStack(security, m_dnsServers,0,false,0,compression));
        
        m_stack.reset(new SipStack(security, m_dnsServers,0,false,0));
        getTransport();
        
        m_stack->statisticsManagerEnabled() = false;
        
        m_userAgent = new DialogUsageManager(*m_stack);
        
        m_userAgent->setClientRegistrationHandler(this);
        m_userAgent->setInviteSessionHandler(this);
        
        createMasterProfile();
        m_userAgent->setMasterProfile(m_masterProfile);
        
        std::auto_ptr<KeepAliveManager> keepAlive(new KeepAliveManager);
        m_userAgent->setKeepAliveManager(keepAlive);
        
        m_pollGrp = FdPollGrp::create();
        m_interruptor = new EventThreadInterruptor(*m_pollGrp);
        m_stackThread = new EventStackThread(*m_stack, *m_interruptor,*m_pollGrp);
        
        m_stack->run();
        m_stackThread->run();
    }
    
    m_clientAuth = std::auto_ptr<ClientAuthManager>(new ClientAuthManager);
    m_userAgent->setClientAuthManager(m_clientAuth);
    
    m_clientAddress = NameAddr(address.c_str());
    
    if (m_isJwt == false) {
        setupCredential(m_username, m_password);
    }
    
    
    m_masterProfile->setDefaultFrom(m_clientAddress);
    
    SharedPtr<SipMessage> regMessage = m_userAgent->makeRegistration(m_clientAddress);
    
    if (m_headers.size() != 0){
        for (auto const& [key, val] : m_headers)
        {
            const Data headerName(key);
            resip::ExtensionHeader h_Tmp(headerName);
            handleLog("setupTransport: setting extra header | key : " + key  + " value : " + val);
            regMessage->header(h_Tmp).push_back(StringCategory(val.c_str()));
        }
    }
    
    if (contact_url.size() != 0){
        Data contactString(contact_url);
        NameAddr contact(contactString);
        handleLog("setupTransport: removing old contact header and adding new : " + contact_url);
        regMessage->header(h_Contacts).pop_back();
        regMessage->header(h_Contacts).push_back(contact);
    }
    
//    if (registeredContact.uri().user().size() != 0 && isProxyRegister == false){
//        std::string user = registeredContact.uri().user().c_str();
//        handleLog("setupTransport: already have registered contact updating it..." + user);
//        regMessage->header(h_Contacts).pop_back();
//        regMessage->header(h_Contacts).push_back(registeredContact);
//    }
//
    regMessage->header(h_Expires).value() = m_reg_timeout;
    
//    if (isProxyRegister == true){
//        if (!m_outboundProxy.host().empty()){
//            std::string aor = m_outboundProxy.getAor().c_str();
//            handleLog("setupTransport: setting route header in register message " + aor);
//            regMessage->header(h_Routes).push_back(NameAddr(m_outboundProxy));
//        }
//    }
    
    handleLog("setupTransport: sending register message ");
    m_userAgent->send(regMessage);
    
    if (isProxyRegister == false && m_run == false){
        handleLog("setupTransport: ruuning thread is started ");
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        m_run = true;
        m_receiveClosed = false;
        m_receiver = new std::thread(&SipControllerCore::receive, this);
    }
}

void SipControllerCore::getTransport() {
    bool isTransportAdded = false, isFirstAttempt = true;
    while(!isTransportAdded) {
        try {
            if (!isFirstAttempt) tls_transport_port = rand()%((5000 - 5100) + 1) + 5000;
            isFirstAttempt = false;
            tls_key  = m_stack->addTransport(TLS, tls_transport_port)->getKey();
            isTransportAdded = true;
        } catch (...) {
            handleLog("Retry adding transport");
        }
    }
}

void SipControllerCore::setupCredential(std::string username, std::string password){
    handleLog("setupCredential: username : " + username + " password " + password);
    m_masterProfile->setDigestCredential(m_clientAddress.uri().host(), m_clientAddress.uri().user(), password.c_str());
}

void SipControllerCore::createMasterProfile()
{
    handleLog("createMasterProfile");
    m_masterProfile = SharedPtr<MasterProfile>(new MasterProfile);
    m_masterProfile->setInstanceId(m_uri.c_str());
    
    m_masterProfile->clearSupportedMethods();
    m_masterProfile->addSupportedMethod(INVITE);
//    m_masterProfile->addSupportedMethod(UPDATE);
    m_masterProfile->addSupportedMethod(ACK);
    m_masterProfile->addSupportedMethod(CANCEL);
    m_masterProfile->addSupportedMethod(OPTIONS);
    m_masterProfile->addSupportedMethod(BYE);
    m_masterProfile->addSupportedMethod(NOTIFY);
    m_masterProfile->addSupportedMethod(SUBSCRIBE);
    m_masterProfile->addSupportedMethod(INFO);
    m_masterProfile->addSupportedMethod(MESSAGE);
    m_masterProfile->addSupportedMethod(PRACK);
    m_masterProfile->setUacReliableProvisionalMode(MasterProfile::Supported);
    m_masterProfile->setUasReliableProvisionalMode(MasterProfile::SupportedEssential);
    
    // Support Languages
    m_masterProfile->clearSupportedLanguages();
    m_masterProfile->addSupportedLanguage(Token("en"));
    
    // Support Mime Types
    m_masterProfile->clearSupportedMimeTypes();
    m_masterProfile->addSupportedMimeType(INVITE, Mime("application", "sdp"));
    m_masterProfile->addSupportedMimeType(INVITE, Mime("multipart", "mixed"));
    m_masterProfile->addSupportedMimeType(INVITE, Mime("multipart", "signed"));
    m_masterProfile->addSupportedMimeType(INVITE, Mime("multipart", "alternative"));
    m_masterProfile->addSupportedMimeType(OPTIONS,Mime("application", "sdp"));
    m_masterProfile->addSupportedMimeType(OPTIONS,Mime("multipart", "mixed"));
    m_masterProfile->addSupportedMimeType(OPTIONS, Mime("multipart", "signed"));
    m_masterProfile->addSupportedMimeType(OPTIONS, Mime("multipart", "alternative"));
    m_masterProfile->addSupportedMimeType(PRACK, Mime("application", "sdp"));
    m_masterProfile->addSupportedMimeType(PRACK, Mime("multipart", "mixed"));
    m_masterProfile->addSupportedMimeType(PRACK, Mime("multipart", "signed"));
    m_masterProfile->addSupportedMimeType(PRACK, Mime("multipart", "alternative"));
    m_masterProfile->addSupportedMimeType(UPDATE, Mime("application", "sdp"));
    m_masterProfile->addSupportedMimeType(UPDATE, Mime("multipart", "mixed"));
    m_masterProfile->addSupportedMimeType(UPDATE, Mime("multipart", "signed"));
    m_masterProfile->addSupportedMimeType(UPDATE, Mime("multipart", "alternative"));
    
    // Supported Options Tags
    m_masterProfile->clearSupportedOptionTags();
    //mMasterProfile->addSupportedOptionTag(Token(Symbols::Replaces));
    m_masterProfile->addSupportedOptionTag(Token(Symbols::Timer));     // Enable Session Timers
    
    // Supported Schemes
    m_masterProfile->clearSupportedSchemes();
    m_masterProfile->addSupportedScheme("sip");
    m_masterProfile->addSupportedScheme("Digest");
    
    // Validation Settings
    m_masterProfile->validateContentEnabled() = false;
    m_masterProfile->validateContentLanguageEnabled() = false;
    m_masterProfile->validateAcceptEnabled() = false;
    
    // Have stack add Allow/Supported/Accept headers to INVITE dialog establishment messages
    m_masterProfile->clearAdvertisedCapabilities(); // Remove Profile Defaults, then add our preferences
    m_masterProfile->addAdvertisedCapability(Headers::Allow);
    //_masterProfile->addAdvertisedCapability(Headers::AcceptEncoding);  // This can be misleading - it might specify what is expected in response
    m_masterProfile->addAdvertisedCapability(Headers::AcceptLanguage);
    m_masterProfile->addAdvertisedCapability(Headers::Supported);
    m_masterProfile->setMethodsParamEnabled(true);
    
    m_masterProfile->setDefaultRegistrationTime(m_reg_timeout);
    m_masterProfile->setDefaultRegistrationRetryTime(0);
    
    if (!m_outboundProxy.host().empty()){
        m_masterProfile->setOutboundProxy(m_outboundProxy);
        m_masterProfile->addSupportedOptionTag(Token(Symbols::Outbound));
    }
    
    //  m_masterProfile->setUserAgent("PlivoTestIOS-v1.2.0");PlivoVoiceKit.framework
    m_masterProfile->setUserAgent(Data(m_userAgentName));
    m_masterProfile->setKeepAliveTimeForDatagram(25);
    m_masterProfile->setKeepAliveTimeForStream(25);
    m_masterProfile->setDefaultStaleCallTime(60);
}

void SipControllerCore::registerTimeOut(int time){
    handleLog(" registerTimeOut() m_reg_timeout " + std::to_string(time));
    m_reg_timeout = time;
}

void SipControllerCore::resetStack(){
    handleLog(" resetStack() ");
    
    handleLog(" resetStack() going ahead for reset stack");
    
    if (m_userAgent != NULL){
        m_userAgent->shutdown(this);
        m_userAgent = NULL;
    }
    
    if (m_stackThread != NULL){
        m_stackThread->shutdown();
        m_stackThread->join();
    }
    
    if (m_stack != NULL){
        m_stack->removeTransport(tls_key);

        if (m_stack)
            m_stack.reset();
    }
    isRegistrationInProgress = false;
}

void SipControllerCore::onDumCanBeDeleted(){
    handleLog(" onDumCanBeDeleted() ");
}

void SipControllerCore::unregisterUser(std::map<std::string,std::string> headers) {
    if (headers.size() != 0) {
        m_headers = headers;
    }
    
    handleLog("SipControllerCore logout called");
    m_reg_timeout = 0;

    handleLog("SipControllerCore unregister " + m_app_id + " cert " + m_cert_id);
    reRegister();
        
}

void SipControllerCore::createSession(std::string remoteUser, std::string localSdp, std::map<std::string,std::string> headers = {}){
    mProgress = Dialing;
    handleLog("createSession remote user " + remoteUser + " local sdp : " + localSdp);
    //Block start
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        m_headers = headers;
        m_isCaller = true;
        m_remoteUri = remoteUser;
    }
   
    bool localCandidatesCollected;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        m_localSdp = localSdp;
//        m_localSdpSet = true;
        localCandidatesCollected = m_localCandidatesCollected;
    }
    
    if (localCandidatesCollected){
        handleLog("createSession sending offer sdp outgoing " + std::to_string(m_localCandidates.size()));
        sendSdpOffer(headers);
    }
}









/*
 --------------------------------------------------------------------------------------------------------------------
 *
 *
 * Note: These blocks should run after registration
 MARK: Application layer calling methods
 --------------------------------------------------------------------------------------------------------------------
 */
void SipControllerCore::acceptSession(std::string localSdp){
    handleLog("acceptSession(localsdp) " + localSdp);
    
    mProgress = Ringing;
    m_inInBoundAccepted = true;
    
    m_localSdp = localSdp;
    
    if (m_localCandidatesCollected){
        handleLog("acceptSession localCandidatesCollected sendSdpAnswer called");
        sendSdpAnswer();
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        m_inCall = true;
    }
    
    handleLog("acceptSession executed");
}

void SipControllerCore::rejectOtherCall(){
    handleLog("rejectOtherCall() already on another call. rejecting second call.");
    m_otherServerInviteSession->reject(486);
}

/// Call got rejected from UAC side. Make sure now onTerminated is not getting called
/// Note : It can lead to app crash!
void SipControllerCore::reject(){
    InfoLog(<<"Rejecting call in SIP Controle layer");
    handleLog("Rejecting call in SIP Controle layer");
   
    if (mProgress == Done && isUACRejected == true){
        handleLog("reject() already rejected cannot accept repeat reject request | returing from here");
        return;
    }
    
    InfoLog(<<"Info Rejecting call in SIP Controle layer");
    
    isUACRejected = true;
    
    m_localCandidatesCollected = false;

    m_inCall = false;
    
    SipCallHandler *callHandler;
    
    callHandler = m_callHandler;
    
    m_inInBoundAccepted = false;
    m_isCaller = false;
    m_remoteSdpSet = false;
    m_localSdp.clear();
    m_remoteSdp.clear();
    m_localCandidates.clear();
    m_current_callid.clear();
    
    if (m_serverInviteSession != nullptr){
        if(!m_serverInviteSession->isConnected()){
            mProgress = Done;
            handleLog("Rejecting with status code 486");
            m_serverInviteSession->reject(486);
            m_serverInviteSession = nullptr;
            callHandler->handleCall(TerminateCall, "Local Rejected");
        }else{
            handleLog("Rejecting with hangup");
            terminateSession();
        }
    }else{
        mProgress = Done;
        callHandler->handleCall(TerminateCall, "Local Rejected");
        handleLog("reject() m_serverInviteSession is nil");
    }
    
}

void SipControllerCore::networkChange(std::map<std::string,std::string> headers){
    /*If call is in the ringing state do not try to refresh the targets,
    instead terminate the call.
     
    isCallRinging variable changes if incoming | outgoing call is in ringing state.
    */
    refresh_targets = !isCallRinging;
    if (m_stack != NULL){
        m_stack->removeTransport(tls_key);
        sleep(1);
        getTransport();
    }
    
    if (headers.size() != 0) {
        m_headers = headers;
    }
    
    reRegister();
}

void SipControllerCore::refreshTargetsForInvite() {
        std::string address = "sip:" + m_username + "@" + m_domain + ";transport=tls";
        handleLog("reINVITE sending... : " + address);
        if (m_clientInviteSession != nullptr) {
            m_clientInviteSession->targetRefresh(NameAddr(address.c_str()));
        }

        if (m_serverInviteSession != nullptr) {
            m_serverInviteSession->targetRefresh(NameAddr(address.c_str()));
        }
    }

void SipControllerCore::ringing(){
    handleLog("Sending ringing 180 in SIP Controle layer");
    if (m_serverInviteSession){
        m_serverInviteSession->provisional(180);
    }
}

void SipControllerCore::onIceCandidate(std::string &sdp, std::string &mid){
    handleLog("onIceCandidate");
    
    {
        IceCandidate iceCandidate;
        iceCandidate.mid = mid;
        iceCandidate.candidate = sdp;
        m_localCandidates.push_back(iceCandidate);
    }
}

void SipControllerCore::onIceGatheringFinished(){
    handleLog("onIceGatheringFinished");
    
    if (mProgress == Done){
        handleLog("onIceGatheringFinished() session is destroyed due to progress == done | returing from here");
        return;
    }
    
    bool isCaller;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        isCaller = m_isCaller;
    }
    
    handleLog("onIceGatheringFinished step 2 " + std::to_string(isCaller) + std::to_string(m_inInBoundAccepted));
    
    if (isCaller == true){
        handleLog("onIceGatheringFinished sending offer outgoing " + std::to_string(m_localCandidates.size()));
        if (m_headers.empty() == false){
            sendSdpOffer(m_headers);
        }else{
            sendSdpOffer();
        }
        
        m_localCandidatesCollected = true;
        
        {
            std::lock_guard<std::mutex> lock(m_controllerMutex);
            m_inCall = true;
        }
        
    } else if (!isCaller && m_inInBoundAccepted){
        handleLog("onIceGatheringFinished sending answer");
        sendSdpAnswer();
        m_localCandidatesCollected = true;
        
        {
            std::lock_guard<std::mutex> lock(m_controllerMutex);
            m_inCall = true;
        }
    }else{
        handleLog("onIceGatheringFinished incoming call ice gathering state finish");
        m_localCandidatesCollected = true;
        
        {
            std::lock_guard<std::mutex> lock(m_controllerMutex);
            m_inCall = true;
        }
    }
}

void SipControllerCore::terminateSession(){
    
    handleLog("terminateSession requested from application layer");
    m_localCandidatesCollected = false;
    
    if (mProgress == Done){
        handleLog("terminateSession() already destroyed due to progress == done | returing from here");
        return;
    }
    
    mProgress = Done;
    m_inCall = false;
    
    if (m_clientInviteSession){
        handleLog("terminateSession m_clientInviteSession");
        m_clientInviteSession->end(InviteSession::UserHangup);
    }
    
    if (m_serverInviteSession){
        handleLog("terminateSession m_serverInviteSession");
        m_serverInviteSession->end(InviteSession::UserHangup);
    }
    
    handleLog("terminateSession 2");
    
    SipCallHandler *callHandler;
    
    callHandler = m_callHandler;
    callHandler->handleCall(TerminateCall, "Local Ignored");
    m_inInBoundAccepted = false;
    m_isCaller = false;
    m_remoteSdpSet = false;
    m_localSdp.clear();
    m_remoteSdp.clear();
    m_localCandidates.clear();
    m_current_callid.clear();
    isUACRejected = false;
    isCallRinging = false;
    m_headers.clear();

    
    m_clientInviteSession = nullptr;
    m_serverInviteSession = nullptr;
    
    handleLog("terminateSession freed all memory");
}







/*
 --------------------------------------------------------------------------------------------------------------------
 *
 *
 *These blocks should run after registration
 MARK: InviteSessionHandle
 *
 --------------------------------------------------------------------------------------------------------------------
 */

/// called when an dialog enters the terminated state - this can happen
/// after getting a BYE, Cancel, or 4xx,5xx,6xx response - or the session
/// times out
void SipControllerCore::onTerminated(InviteSessionHandle, InviteSessionHandler::TerminatedReason reason, const SipMessage* msg){
    handleLog("onTerminated() called");
    
    //call state is now terminated. Hence, resetting this flag to false now.
    isCallRinging = false;

    if (isSecondaryUAC == true){
        isSecondaryUAC = false;
        handleLog("onTerminated() already on another call | returing from here");
        return;
    }
    
    m_localCandidatesCollected = false;
    
    if (mProgress == Done){
        handleLog("onTerminated() already destroyed due to progress == done | returing from here");
        return;
    }
    
    mProgress = Done;
    
    SipCallStateHandler *callStateHandler;
    bool inCall;
    
    callStateHandler = m_callStateHandler;
    
    SipCallHandler *callHandler;
    
    callHandler = m_callHandler;
    inCall = m_inCall;
    
    if (isUACRejected){
        callHandler->handleCall(TerminateCall, "Local Rejected");
        handleLog("onTerminated() iSUACRejected = true | returing from here");
        return;
    }
    
    //Some basic reset
    Data reasonData;
    std::string reasonDataString;
    unsigned int statusCode = 603;
    
    switch(reason)
    {
        case InviteSessionHandler::RemoteBye:
            reasonData = "received a BYE from peer";
            reasonDataString = "Remote Terminated";
            statusCode = 200;//Making it 200 bcz i m expecting call terminated after successfully connected
            break;
        case InviteSessionHandler::RemoteCancel:
            reasonData = "received a CANCEL from peer";
            reasonDataString = "Remote Ignored";
            statusCode = 487;
            break;
        case InviteSessionHandler::Rejected:
            reasonData = "received a rejection from peer";
            reasonDataString = "Remote Rejected";
            statusCode = 486;
            break;
        case InviteSessionHandler::LocalBye:
            reasonData = "ended locally via BYE";
            reasonDataString = "Local Terminated";
            break;
        case InviteSessionHandler::LocalCancel:
            reasonData = "ended locally via CANCEL";
            reasonDataString = "Local Ignored";
            break;
        case InviteSessionHandler::Replaced:
            reasonData = "ended due to being replaced";
            reasonDataString = "Remote Replaced";
            break;
        case InviteSessionHandler::Referred:
            reasonData = "ended due to being reffered";
            reasonDataString = "Remote Referred";
            break;
        case InviteSessionHandler::Error:
            reasonData = "ended due to an error";
            reasonDataString = "Remote Error";
            break;
        case InviteSessionHandler::Timeout:
            reasonData = "ended due to a timeout";
            reasonDataString = "Remote Timeout";
            break;
        default:
            reasonData = "default error";
            reasonDataString = "Remote Error";
            break;
    }
    
    
    // 486 - Busy
    // 487 - Cancelled
    if(msg){
        if(msg->isResponse()){
            statusCode = msg->header(h_StatusLine).responseCode();
        }
    }
    
    if (statusCode == 486){
        reasonDataString = "Remote Rejected";
    }else if (statusCode == 487){
        reasonDataString = "Remote Ignored";
    }
    
    if(msg){
        InfoLog(<< "InviteSessionHandle onTerminated: status code = " << statusCode <<" reason= " << reasonData << ", msg=" << msg->brief());
    }else{
        InfoLog(<< "InviteSessionHandle onTerminated: reason=" << reasonData);
    }
    
    callStateHandler->handleCallState(reasonDataString, statusCode);
    
    if (callHandler)
        callHandler->handleCall(TerminateCall, reasonDataString);
    
    if (!inCall){
        handleLog("onTerminated() already destroyed | returing from here");
        return;
    }
    
    m_inInBoundAccepted = false;
    
    m_clientInviteSession = nullptr;
    m_serverInviteSession = nullptr;
    
    m_current_callid.clear();
    m_inCall = false;
    m_isCaller = false;
    m_remoteSdpSet = false;
    m_localSdp.clear();
    m_remoteSdp.clear();
    m_localCandidates.clear();
    m_headers.clear();
}

void SipControllerCore::onReadyToSend(InviteSessionHandle, SipMessage& msg) {
        handleLog("@SipControllerCore::onReadyToSend:-  Intercepting The Msg \n");

        if (msg.isRequest() && !m_outboundProxy.host().empty()) {
            handleLog("@SipControllerCore::onReadyToSend:- Setting Force Target To Outbound Proxy");
            msg.setForceTarget(m_outboundProxy);
        }
    }

/// Outgoing call - called when an answer is received - has nothing to do with user
/// answering the call
void SipControllerCore::onAnswer(InviteSessionHandle, const SipMessage& msg, const SdpContents& sdp){
    handleLog("InviteSessionHandle onAnswer() Answer received | Outgoing call flow");
    //Now as the user has received the answer for the outgoing call. Resetting this flag to false.
    isCallRinging = false;
    
    SipCallStateHandler *callStateHandler;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        callStateHandler = m_callStateHandler;
    }
    
    callStateHandler->handleCallState("CallAccepted", msg.header(h_StatusLine).responseCode());
}


/// Incoming call - called when an offer is received - must send an answer soon after this
void SipControllerCore::onOffer(InviteSessionHandle, const SipMessage& msg, const SdpContents& sdp){
    handleLog("InviteSessionHandle onOffer() Offer received | Incoming call flow");
   
    //Setting this to true as the incoming call is received and it will be in the ringing state initially
    isCallRinging = true;
    
    SipCallStateHandler *callStateHandler;
    SipCallHandler *callHandler;
    SipSDPHandler *sdpHandler;
    
    resip::H_From headerType;
    H_From::Type from = msg.header(headerType);
    const char* fromC = from.uri().user().c_str();
    
    ///Call Handler
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        callHandler = m_callHandler;
    }
    if (callHandler){
        callHandler->handleCall(IncomingCall, fromC);
    }
    
    ///Call State Handler
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        callStateHandler = m_callStateHandler;
    }
    callStateHandler->handleCallState("EarlyMedia", 183);
    
    ///SDP Handler
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        sdpHandler = m_sdpHandler;
    }
    HeaderFieldValue headerFieldValue = msg.getRawBody();
    std::string remoteSdp = sdp.getBodyData().c_str();
    sdpHandler->handleSDP(remoteSdp);
    
    handleLog("SDP Offer incoming \n " + remoteSdp);
    
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        m_isCaller = false;
        m_inCall = true;
        m_remoteSdp = remoteSdp;
        m_remoteSdpSet = true;
    }
}

/// called when a dialog initiated as a UAS enters the connected state
void SipControllerCore::onConnected(InviteSessionHandle, const SipMessage& msg){
    mProgress = Connected;
    handleLog("InviteSessionHandle Session connected");
}

/// called when an Invite w/out offer is sent, or any other context which
/// requires an offer from the user
void SipControllerCore::onOfferRequired(InviteSessionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onOfferRequired");
}

/// called if an offer in a UPDATE or re-INVITE was rejected - not real
/// useful. A SipMessage is provided if one is available
void SipControllerCore::onOfferRejected(InviteSessionHandle, const SipMessage* msg){
    handleLog("InviteSessionHandle onOfferRejected");
}

/// called when INFO message is received
/// the application must call acceptNIT() or rejectNIT()
/// once it is ready for another message.
void SipControllerCore::onInfo(InviteSessionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onInfo");
}

/// called when response to INFO message is received
void SipControllerCore::onInfoSuccess(InviteSessionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onInfoSuccess");
}

void SipControllerCore::onInfoFailure(InviteSessionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onInfoFailure");
}

/// called when MESSAGE message is received
void SipControllerCore::onMessage(InviteSessionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onMessage");
}

/// called when response to MESSAGE message is received
void SipControllerCore::onMessageSuccess(InviteSessionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onMessageSuccess");
}

void SipControllerCore::onMessageFailure(InviteSessionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onMessageFailure");
}

/// called when an REFER message is received.  The refer is accepted or
/// rejected using the server subscription. If the offer is accepted,
/// DialogUsageManager::makeInviteSessionFromRefer can be used to create an
/// InviteSession that will send notify messages using the ServerSubscription
void SipControllerCore::onRefer(InviteSessionHandle, ServerSubscriptionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onRefer");
}

void SipControllerCore::onReferNoSub(InviteSessionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onReferNoSub");
}

/// called when an REFER message receives a failure response
void SipControllerCore::onReferRejected(InviteSessionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onReferRejected");
}

/// called when an REFER message receives an accepted response
void SipControllerCore::onReferAccepted(InviteSessionHandle, ClientSubscriptionHandle, const SipMessage& msg){
    handleLog("InviteSessionHandle onReferAccepted");
}





/*
 --------------------------------------------------------------------------------------------------------------------
 *
 *
 *These blocks should run after registration
 MARK: Register ClientRegistrationHandle
 *
 *
 *
 --------------------------------------------------------------------------------------------------------------------
 */
/// Called when registraion succeeds or each time it is sucessfully
/// refreshed (manual refreshes only).
void SipControllerCore::onSuccess(ClientRegistrationHandle, const SipMessage& response){
    handleLog("ClientRegistrationHandle onSuccess()");
    
    retry_count = 1;
    isRegistrationInProgress = false;
    sipLogString = "";
    if (refresh_targets == true) {
        refresh_targets = false;
        refreshTargetsForInvite();
    }
    
    
    if (mProgress == Connected){
        handleLog("Register onSuccess() already on another call No need to notify. returing from here");
        return;
    }
    
    resip::H_From headerType;
    H_From::Type from = response.header(headerType);
    
    Data uri = from.uri().getAor();
    const char* fromC = from.uri().user().c_str();
    
//    resip::H_Contacts contactHeaderType;
//    H_Contacts::Type contacts = response.header(contactHeaderType);
//
//    if(!contacts.empty()){
//        registeredContact = contacts.front();
//        InfoLog(<< registeredContact);
//    }
    
    handleLog("ClientRegistrationHandle call info in onSuccess");
    
    isProxyRegister = false;
    
    if (response.header(h_Vias).empty() == false){
        Tuple publicAddress = processIpAndPort(response);
        
        if(publicAddress.getType() != UNKNOWN_TRANSPORT)
        {
            std::string ip = Tuple::inet_ntop(publicAddress).c_str();
            std::string port = std::to_string(publicAddress.getPort());
            if (ip.size() != 0 && port.size() != 0){
                m_public_ip_port = ip + ":" + port;
                handleLog("resolving ip and port "  + ip + port);
            }
        }
    }
    
    //terminate the call if the call is in ringing state and re-registration was performed due to network change.
    if (isCallRinging) {
        terminateSession();
        return;
    }
    
    SipRegistrationHandler *registrationHandler;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        registrationHandler = m_registrationHandler;
    }
    
    registrationHandler->handleRegistration(Registered, fromC);
}

/// Called when all of my bindings have been removed
void SipControllerCore::onRemoved(ClientRegistrationHandle, const SipMessage& response)
{
    handleLog("ClientRegistrationHandle onRemoved");
    m_receiveMutex.lock();
    m_run = false;
    m_receiveMutex.unlock();
    
    m_receiveMutex.lock();
    m_receiveClosed = true;
    m_receiveMutex.unlock();
    
    {
        std::unique_lock<std::mutex> receiveConditionMutex(m_receiveMutex);
        if (!m_receiveClosed)
            m_receiveCondition.wait(receiveConditionMutex);
    }
    
    IPSingleton* ipSingleton = IPSingleton::getInstance();
    ipSingleton->clearAddress();
    m_inInBoundAccepted = false;
    m_inCall = false;
    m_isCaller = false;
    //    m_localSdpSet = false;
    m_remoteSdpSet = false;
    m_localCandidatesCollected = false;
    m_localSdp.clear();
    m_remoteSdp.clear();
    m_localCandidates.clear();
    m_inInBoundAccepted = false;
    m_isJwt = false;
    m_headers.clear();

    resetStack();

    m_registrationHandler->handleRegistration(NotRegistered, "Logout");
}

/// From resip/dum/RegistrationHandler.hxx
/// call on Retry-After failure.
/// return values: -1 = fail, 0 = retry immediately, N = retry in N seconds
int SipControllerCore::onRequestRetry(ClientRegistrationHandle, int retrySeconds, const SipMessage& response)
{
    if (retry_count <= REG_REQUEST_RETRY) {
        handleLog("ClientRegistrationHandle onRequestRetry : Retry ");
        retry_count += 1;
        return 2;
    } else {
        handleLog("ClientRegistrationHandle onRequestRetry : Fallback");
        
        moveToFallback();
        return 0;
    }
}

void SipControllerCore::moveToFallback() {
    handleLog("SipControllerCore moveToFallback " + m_fallbackProxyServer);
    std::string switchFallBackProxy = m_proxyServer;
    m_proxyServer = m_fallbackProxyServer;
    m_fallbackProxyServer = switchFallBackProxy;
    IPSingleton* ipSingleton = IPSingleton::getInstance();
    ipSingleton->clearAddress();
    std::string proxyAddress = "sip:" + m_proxyServer + ";transport=tls";
    m_outboundProxy = Uri(Data(proxyAddress));
    retry_count = 1;

    if (!m_outboundProxy.host().empty()) {
        m_masterProfile->setOutboundProxy(m_outboundProxy);
        m_masterProfile->addSupportedOptionTag(Token(Symbols::Outbound));
    }

    isProxyRegister = true;
    std::string sipUri = createUri(m_username);


    std::string contact_url = "<sip:" + m_uri + ";transport=tls;app_id=" + m_app_id + ">";
    setupTransport(sipUri, contact_url);
}

/// Called if registration fails, usage will be destroyed (unless a
/// Registration retry interval is enabled in the Profile)
void SipControllerCore::onFailure(ClientRegistrationHandle, const SipMessage& response)
{
    handleLog("ClientRegistrationHandle onFailure" );
    isRegistrationInProgress  = false;
    
    
    if (handleHeaderErrorCode(response) == false) {
        SipErrorHandler *errorHandler;
        {
            std::lock_guard<std::mutex> lock(m_controllerMutex);
            errorHandler = m_errorHandler;
        }
        
        unsigned int statusCode = 603;
        
        if(response.isResponse()){
            statusCode = response.header(h_StatusLine).responseCode();
        }
        std:: string failureReason = sipLogString = "statuscode: " + std::to_string(statusCode) + "\n" + sipLogString;
        sipLogString = "";
        if (errorHandler)
            errorHandler->handleError(SipSessionError, failureReason);
    }
    
}

    bool SipControllerCore::handleHeaderErrorCode(const SipMessage &message) {
       for (auto &&i :message.getRawUnknownHeaders()) {
           std::string value = message.header(ExtensionHeader(i.first)).front().value().c_str();
           std::string  header = i.first.c_str();
           std::string send = value + "@@" + sipLogString;
           if(header == "X-Plivo-Jwt-Error-Code"){
               m_registrationHandler->handleRegistration(NotRegisteredJWT, send);
               sipLogString = "";
               return true;
           }
       }
       return false;
   }

/// Called when a TCP or TLS flow to the server has terminated.  This can be caused by socket
/// errors, or missing CRLF keep alives pong responses from the server.
// Called only if clientOutbound is enabled on the UserProfile and the first hop server
/// supports RFC5626 (outbound).
/// Default implementation is to immediately re-Register in an attempt to form a new flow.
void SipControllerCore:: onFlowTerminated(ClientRegistrationHandle){
    handleLog("ClientRegistrationHandle onFlowTerminated" );
}





/*
 --------------------------------------------------------------------------------------------------------------------
 *
 * Call flow handlers method from reSIProcate
 * These blocks should run after registration.
 MARK: Call flow | InviteSessionHandle
 *
 --------------------------------------------------------------------------------------------------------------------
 */
/// called when an initial INVITE or the intial response to an outgoing invite
void SipControllerCore::onNewSession(ServerInviteSessionHandle sis, InviteSession::OfferAnswerType oat, const SipMessage& msg){
    handleLog("Incoming call.....onNewSession()");
    isSecondaryUAC = false;
    
    if (mProgress == Connected){
        handleLog("onNewSession() already on another call. init second call session");
        isSecondaryUAC = true;
        m_otherServerInviteSession = sis.get();
        rejectOtherCall();
        return;
    }
    
    m_current_callid = getCallId(msg);
   
    //Call info handler
    SipCallInfoHandler *callInfoHandler;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        callInfoHandler = m_callInfoHandler;
    }
    
    callInfoHandler->handleCallInfo(processCallInfo(msg));
    
    handleLog("Incoming call.....onNewSession() callid : " + m_current_callid);
    
    mProgress = Ringing;
    
    if (isValidUserAgent(msg)){
        handleLog("onNewSession() found valid user agent init ServerInviteSession");
        m_serverInviteSession = sis.get();
        if (isUACRejected){
            isUACRejected = false;
            reject();
            handleLog("terminating session rejecting");
        }
        isUACRejected = false;
    }else{
        isUACRejected = false;
        handleLog("ServerInviteSessionHandle onNewSession: Error Incoming call from invalid user agent");
    }
}

/// called when an initial INVITE or the intial response to an outgoing invite
void SipControllerCore::onNewSession(ClientInviteSessionHandle cis, InviteSession::OfferAnswerType oat, const SipMessage& msg){
    handleLog("Outgoing call.....onNewSession()");
    isUACRejected = false;
    
    m_current_callid = getCallId(msg);
    
    //Call info handler
    SipCallInfoHandler *callInfoHandler;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        callInfoHandler = m_callInfoHandler;
    }
    
    callInfoHandler->handleCallInfo(processCallInfo(msg));
    
    handleLog("Outgoing call.....onNewSession() callid : " + m_current_callid);
    
    
    if (mProgress == Done){
        handleLog("Outgoing call.....onNewSession() mProgress == Done terminating call session");
        mProgress = Dialing;
        
        if (isValidUserAgent(msg)){
            {
                std::lock_guard<std::mutex> lock(m_controllerMutex);
                m_clientInviteSession = cis.get();
                
            }
        }else{
            handleLog("ClientInviteSessionHandle onNewSession: in (mProgress == Done) Error Outgoing call not a valid user agent");
        }
        
        terminateSession();
    }else{
        mProgress = Dialing;
        
        if (isValidUserAgent(msg)){
            {
                std::lock_guard<std::mutex> lock(m_controllerMutex);
                m_clientInviteSession = cis.get();
            }
            
            SipSDPHandler *sdpHandler;
            {
                std::lock_guard<std::mutex> lock(m_controllerMutex);
                sdpHandler = m_sdpHandler;
            }
            std::string remoteSdp = msg.getContents()->getBodyData().c_str();
            handleLog("SDP Answer | outgoing call flow remote SDP : "+remoteSdp);
            
            sdpHandler->handleSDP(remoteSdp);
            
            {
                m_inCall = true;
                std::lock_guard<std::mutex> lock(m_controllerMutex);
                m_remoteSdp = remoteSdp;
                m_remoteSdpSet = true;
            }
        }else{
            handleLog("ClientInviteSessionHandle onNewSession: Error Outgoing call not a valid user agent");
        }
        
    }
    
}

/// Received a failure response from UAS
void SipControllerCore::onFailure(ClientInviteSessionHandle, const SipMessage& msg){
    m_current_callid = getCallId(msg);
   
    //Call info handler
    SipCallInfoHandler *callInfoHandler;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        callInfoHandler = m_callInfoHandler;
    }
    handleHeaderErrorCode(msg);
    callInfoHandler->handleCallInfo(processCallInfo(msg));
    handleLog("ClientInviteSessionHandle onFailure: UAS");
}

/// called when an in-dialog provisional response is received that contains a body | Note: To handle ringing state
void SipControllerCore::onEarlyMedia(ClientInviteSessionHandle, const SipMessage& msg, const SdpContents& sdp){
    handleLog("ClientInviteSessionHandle onEarlyMedia");
    mProgress = Dialing;
    
    SipCallStateHandler *callStateHandler;
    {
        std::lock_guard<std::mutex> lock(m_controllerMutex);
        callStateHandler = m_callStateHandler;
    }
    callStateHandler->handleCallState("EarlyMedia", getStatusCode(msg));
}

/// called when dialog enters the Early state - typically after getting 18x
void SipControllerCore::onProvisional(ClientInviteSessionHandle, const SipMessage& msg){
    mProgress = Dialing;
    handleLog("ClientInviteSessionHandle onProvisional");
}

/// called when a dialog initiated as a UAC enters the connected state
void SipControllerCore::onConnected(ClientInviteSessionHandle cis, const SipMessage& msg){
    mProgress = Connected;
    handleLog("ClientInviteSessionHandle Session connected");
}

/// called when a fork that was created through a 1xx never receives a 2xx
/// because another fork answered and this fork was canceled by a proxy.
void SipControllerCore::onForkDestroyed(ClientInviteSessionHandle){
    handleLog("ClientInviteSessionHandle onForkDestroyed");
}

/** UAC gets no final response within the stale call timeout (default is 3
 * minutes). This is just a notification. After the notification is
 * called, the InviteSession will then call
 * InviteSessionHandler::terminate() */
void SipControllerCore::onStaleCallTimeout(ClientInviteSessionHandle){
    handleLog("ClientInviteSessionHandle onStaleCallTimeout");
}

/// called when a 3xx with valid targets is encountered in an early dialog
/// This is different then getting a 3xx in onTerminated, as another
/// request will be attempted, so the DialogSet will not be destroyed.
/// Basically an onTermintated that conveys more information.
/// checking for 3xx respones in onTerminated will not work as there may
/// be no valid targets.
void SipControllerCore::onRedirected(ClientInviteSessionHandle, const SipMessage& msg){
    handleLog("ClientInviteSessionHandle onRedirected");
}

std::string SipControllerCore::getPublicIp() {
    return m_public_ip;
}

bool SipControllerCore::checkIfSipMessage(std::string value) {
    std::string prefix1 = "SIP/";
    std::string prefix2 = "REGISTER";
    if (value.find(prefix2) != std::string::npos || value.find(prefix1) != std::string::npos){
        return true;
    }
    return false;
}

std::string SipControllerCore::getDateString() {
       time_t rawtime;
       struct tm * timeinfo;
       char buffer[80];
       time (&rawtime);
       timeinfo = localtime(&rawtime);
       strftime(buffer,sizeof(buffer),"%d-%m-%Y %H:%M:%S",timeinfo);
       std::string str(buffer);
       return str;
   }


}
/*
//Outgoing call flow
SipControllerCore:: ***sendSdpOffer
SipControllerCore:: ***onAnswer
SipControllerCore:: ***onTerminated
 
//Incoming call flow
SipControllerCore:: ***onOffer
SipControllerCore:: ***sendSdpAnswer
SipControllerCore:: ***onTerminated
 * */
