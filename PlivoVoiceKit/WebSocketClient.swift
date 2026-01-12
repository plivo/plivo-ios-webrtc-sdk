//
//  WebSocketClient.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 23/04/21.
//

import Foundation

class WebSocketClient:NSObject{
    
    private var webSocket:WebSocket?
    
    var statsMessage = [String]()
    var readyState = false
    
    override init(){
        LogManager.shared.log("init WebSocketClient", level: .alert)
    }
    
    deinit {
        webSocket?.close()
        LogManager.shared.log("deinit WebSocketClient", level: .alert)
    }
    
    func openWebSocket(messageArray:[String]){
        guard let url = Constant.STATSSOCKET_URL else {
            LogManager.shared.log("WebSocketClient | Issue with the url", level: .error)
            return
        }
        
        readyState = false
        
        LogManager.shared.log("WebSocketClient | Opening 3rd party Websocket previous queue count : \(messageArray.count)", level: .debug)
        webSocket = nil
        webSocket = WebSocket(url: url)
        webSocket?.delegate = self
        webSocket?.open()
        
        statsMessage = messageArray
    }
    
    func sendMessageWebSocket( messageArray:inout [String]){
        for eachMessage in messageArray {
            LogManager.shared.log("WebSocketClient | Sending iOS Stats through 3rd party: \(eachMessage)", level: .debug)
            webSocket?.send(eachMessage)
        }
        messageArray.removeAll()
    }
    
}

extension WebSocketClient:WebSocketDelegate{
    func webSocketOpen() {
        LogManager.shared.log("WebSocketClient | 3rd party Websocket Connected", level: .debug)
        readyState = true
        sendMessageWebSocket(messageArray: &statsMessage)
    }
    
    func webSocketClose(_ code: Int, reason: String, wasClean: Bool) {
        LogManager.shared.log("WebSocketClient | 3rd party Websocket closing with code \(code) reason \(String(describing: reason))", level: .debug)
    }
    
    func webSocketError(_ error: NSError) {
        readyState = false
        LogManager.shared.log("WebSocketClient | 3rd party Websocket Failed with Error: \(error.localizedDescription)", level: .debug)
    }
    
    func webSocketMessageText(_ text: String) {
        LogManager.shared.log("WebSocketClient | 3rd party Websocket Received: \(text)", level: .debug)
    }
    
    func webSocketMessageData(_ data: Data) {
        LogManager.shared.log("WebSocketClient | 3rd party Websocket Received: \(String(describing: data))", level: .debug)
    }
    
    func webSocketPong() {
        LogManager.shared.log("WebSocketClient | 3rd party Websocket didReceivePong", level: .debug)
    }
}
