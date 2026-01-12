import Foundation


class PlivoQueue {
    var fileUrl: URL?
    var isFlushing: Bool = false
    
    static var shared = PlivoQueue()
    
    public func initFile(fileUrl: URL) {
        self.fileUrl = fileUrl
        
        if !FileManager.default.fileExists(atPath: fileUrl.path) {
            ([] as NSArray).write(to: fileUrl, atomically: true)
        }
        
    }
    
    func enqueue(_ plivoLog: String) {
        DispatchQueue.global(qos: .background).async {
            self.insert(plivoLog)
        }
    }
    
    func insert(_ plivoLog: String) {
        let log = plivoLog + ","
        var storedData = NSArray(contentsOf: self.fileUrl!) as? [String]
        
        guard storedData != nil else {
            print("data while extracting file is nil")
            return
        }
        
        storedData!.append(log)
        
        (storedData as NSArray?)?.write(to: self.fileUrl!, atomically: true)
    }
    
    func dequeue() -> String? {
        var log: String?
        
        DispatchQueue.global(qos: .default).async {
            var storedData = NSArray(contentsOf: self.fileUrl!) as? [String]
            
            guard storedData != nil else {
                print("data while extracting file is nil")
                return
            }
            
            if storedData!.count == 0 {
                return
            }
            
            log = storedData!.first
            
            storedData!.remove(at: 0)
            (storedData as NSArray?)?.write(to: self.fileUrl!, atomically: true)
        }
        return log
    }
    
    func peek() -> String? {
        var log: String?
        DispatchQueue.global(qos: .default).async {
            var storedData = NSArray(contentsOf: self.fileUrl!) as? [String]
            
            guard storedData != nil else {
                print("data while extracting file is nil")
                return
            }
            
            if storedData!.count == 0 {
                return
            }
            
            log = storedData!.first
        }
        return log
    }
    
    func count() -> Int {
        var count: Int = 0
        DispatchQueue.global(qos: .default).sync {
            count = NSArray(contentsOf: self.fileUrl!)!.count
        }
        return count
    }
    
    public func emptyQueue(clear: Bool) -> [String]? {
        var logs: [String]?
        DispatchQueue.global(qos: .default).sync {
            var storedData = NSArray(contentsOf: self.fileUrl!) as? [String]
            
            guard storedData != nil else {
                print("data while extracting file is nil")
                return
            }
            
            if storedData!.count == 0 {
                return
            }

            logs = storedData
            
            if clear {
                storedData = []
                (storedData as NSArray?)?.write(to: self.fileUrl!, atomically: true)
            }
        }
        return logs
    }
}

