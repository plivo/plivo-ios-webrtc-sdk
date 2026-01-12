//
//  PlivoFile.swift
//  PlivoVoiceKit
//
//  Created by Sanyam Jain on 10/11/22.
//

import Foundation

class PlivoFile {
    var isFlushing: Bool = false
    
    func plivoLogQueue() -> URL? {
        var path: URL? = nil
        do {
            path = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true)
            return path?.appendingPathComponent("PlivoLogs.plist")
        } catch {
            print("Error occured while creating the PlivoLogs file")
            return nil
        }
    }
    
    func getSizeInKb(string_array: [String]) -> Double {
        // Get the size of the string array in bytes.
        var size_of_string: Int = 0
        for string in string_array {
            size_of_string += string.count
        }
        
        // Convert the size in bytes to KB.
        let size_in_kb = Double(size_of_string) / 1024
        return size_in_kb
    }
    
    func splitLogsInBatch(logs: [String], interval: Int) -> [[String]] {
        var splitLogs: [[String]] = []
        var currentIndex = 0
        var currentBatch: [String] = []
        
        for log in logs {
            let logSize = log.utf8.count
            
            if currentIndex + logSize > interval {
                currentBatch.append("...continued")
                splitLogs.append(currentBatch)
                currentBatch = []
                currentIndex = 0
            }
            
            currentBatch.append(log)
            currentIndex += logSize
        }
        
        currentBatch.append("...continued")
        
        if !currentBatch.isEmpty {
            splitLogs.append(currentBatch)
        }
        
        return splitLogs
    }
    
    func flush(username: String, jwtToken: String) {
        if let _ = NSClassFromString("XCTest") {
            print("XCTest are runnning")
            PlivoQueue.shared.emptyQueue(clear: true)
            self.isFlushing = false
            return
        }
        
        if isFlushing {
            return
        }
        isFlushing = true
        
        DispatchQueue.global(qos: .default).async { [self] in
            
            let count = PlivoQueue.shared.count()
            
            guard count != 0 else {
                print("cannot flush queue as it is already empty")
                return
            }
            
            let logs = PlivoQueue.shared.emptyQueue(clear: false) ?? []

            
            let logsSize = getSizeInKb(string_array: logs)
            if logsSize >= 20.0 {
                let batches = splitLogsInBatch(logs: logs, interval: 20000)
                for (index,batch) in batches.enumerated() {
                    if index == batches.count-1 {
                        sendLogsToServer(username: username, jwtToken: jwtToken, logs: batch, clearLogs: true)
                    } else {
                        sendLogsToServer(username: username, jwtToken: jwtToken, logs: batch, clearLogs: false)
                    }

                }
            } else {
                sendLogsToServer(username: username, jwtToken: jwtToken, logs: logs, clearLogs: true)
            }
        }
        
    }
    
    func sendLogsToServer(username: String, jwtToken: String, logs: [String], clearLogs: Bool) -> Void {
        var parameterDictionary: [String: Any] = [
            "username": username,
            "logs": logs,
            "sdk_v": Constant.PLIVO_ENDPOINT_VER,
            "sdk_name": Constant.SDK_NAME,
            "user_agent": "name: \(Utils.getDeviceName()), model: \(Utils.getModel()), systemName: \(Utils.getSystemName()), systemVersion: \(Utils.getOSVersion())"
        ]
        
        if !jwtToken.isEmpty {
            parameterDictionary["jwt"] = jwtToken
        }
        var request = URLRequest(url: URL(string: !jwtToken.isEmpty ? Constant.NIMBUS_JWT_LOGS : Constant.NIMBUS_LOGS)!)
       request.httpMethod = "POST"
       request.setValue("application/json", forHTTPHeaderField: "Content-Type")
       guard let httpBody = try? JSONSerialization.data(withJSONObject: parameterDictionary, options: []) else {
           return
       }
       request.httpBody = httpBody
       let session = URLSession.shared
       session.dataTask(with: request) { (data, response, error) in
           if error != nil {
               if (error! as NSError).code == Int(NSURLErrorNotConnectedToInternet) {
                   print("Cannot send the logs to server due to no internet connection")
               }
               print("Error occured while sending logs to server \(String(describing: error))")
               self.isFlushing = false
           }

           if let response = response {
               let statusCode = (response as! HTTPURLResponse).statusCode
               if statusCode == 200 {
                   PlivoQueue.shared.emptyQueue(clear: clearLogs)
                   print("Logs were successfully sent to server")
               } else {
                   print("Error occured while sending logs to server with responsecode \(statusCode)")
               }
           }
           self.isFlushing = false

       }.resume()
    }
}
