//
//  LogManager.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 10/02/21.
//

import Foundation

/**    SEVERITY IN EVENT    Default SMS setting for Syslog Security option. This setting will send all events to remote Syslog system
 0    EMERGENCY    A "panic" condition - notify all tech staff on call? (Earthquake? Tornado?) - affects multiple apps/servers/sites.
 1    ALERT    Should be corrected immediately - notify staff who can fix the problem - example is loss of backup ISP connection.
 2    CRITICAL    Should be corrected immediately, but indicates failure in a primary system - fix CRITICAL problems before ALERT - example is loss of primary ISP connection.
 3    ERROR    Non-urgent failures - these should be relayed to developers or admins; each item must be resolved within a given time.
 4    WARNING    Warning messages - not an error, but indication that an error will occur if action is not taken, e.g. file system 85% full - each item must be resolved within a given time.
 5    NOTICE    Events that are unusual but not error conditions - might be summarized in an email to developers or admins to spot potential problems - no immediate action required.
 6    INFORMATIONAL    Normal operational messages - may be harvested for reporting, measuring throughput, etc. - no action required.
 7    DEBUG    Info useful to developers for debugging the app, not useful during operations. **/

var logs = ""

struct LogManager {
    let lock = NSLock()
    
    static var shared = LogManager()
    
    var logLevel : Level = Level.debug
    
    @objc enum Level: Int {
        case debug = 7
        case info = 6
        case notice = 5
        case warning = 4
        case error = 3
        case critical = 2
        case alert = 1
        case emergency = 0
        case none = -1
    }
   
    private init(){
        print("init LogManager")
    }
    
    mutating func setLogLevel(_ level: Level) {
        self.logLevel = level
    }
    
    mutating func log(_ value:String, level: LogManager.Level = .debug, file: String = #fileID, _ function: String = #function, line: Int = #line, column:Int = #column, d_loc:UnsafeRawPointer = #dsohandle){
        guard level.rawValue <= logLevel.rawValue else {
            return
        }
        let level = processLevel(level: level)

       
        let logValue = formatLog(value, level: level, file: file, function, line: line, column: column, d_loc: d_loc)
        lock.lock()
        logs = logs + logValue
        lock.unlock()

        print(logValue)
        NotificationCenter.default.post(name: NSNotification.Name("log_dump"), object: nil, userInfo: ["LEVEL":level, "LOG":logValue])
    }
    
    func infoLogs(log: String, file: String = #fileID, _ function: String = #function, line: Int = #line, column:Int = #column, d_loc:UnsafeRawPointer = #dsohandle) {
        let logValue = formatLog(log, level: "InfoLogs", file: file, function, line: line, column: column, d_loc: d_loc)
        PlivoQueue.shared.enqueue(logValue)
        print(logValue)
    }
    
    private func formatLog(_ value:String, level: String, file: String = #fileID, _ function: String = #function, line: Int = #line, column:Int = #column, d_loc:UnsafeRawPointer = #dsohandle) -> String {
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        let currentTime = dateFormatter.string(from: today)
        
        var logValue = ""
        if value.contains("SipControllerCore::"){
            logValue = "\r\n \(currentTime) | RESIP | [\(level)] | \(value)"
        }else{
            logValue = "\r\n \(currentTime) | \(file) \(function) | [\(line):\(column)] | [\(level)] | \(value)"
        }
        return logValue
    }
    
    private func processLevel(level:LogManager.Level)->String{
        switch level {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warning:
            return "WARNING"
        case .error:
            return "ERROR"
        case .notice:
            return "NOTICE"
        case .critical:
            return "CRITICAL"
        case .alert:
            return "ALERT"
        case .emergency:
            return "EMERGENCY"
        case .none:
            return "none"
        }
    }
    
}
