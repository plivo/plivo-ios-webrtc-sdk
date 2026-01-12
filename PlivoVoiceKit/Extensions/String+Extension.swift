//
//  StringExtension.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 04/03/21.
//

import Foundation

extension String{
    
    subscript(_ i: Int) -> String {
        let idx1 = index(startIndex, offsetBy: i)
        let idx2 = index(idx1, offsetBy: 1)
        return String(self[idx1..<idx2])
      }

      subscript (r: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: r.lowerBound)
        let end = index(startIndex, offsetBy: r.upperBound)
        return String(self[start ..< end])
      }

      subscript (r: CountableClosedRange<Int>) -> String {
        let startIndex =  self.index(self.startIndex, offsetBy: r.lowerBound)
        let endIndex = self.index(startIndex, offsetBy: r.upperBound - r.lowerBound)
        return String(self[startIndex...endIndex])
      }
    
    var fixedSipUri:String{
        var result = self
        
        if let values = result.splitAtFirst(delimiter: ":"){
            if values.a != ""{
                result = values.b
            }else{
                if result.hasPrefix(":"){
                    result.removeFirst()
                }
            }
        }
        
        if let values = result.splitAtFirst(delimiter: "@"){
            if values.b != ""{
                result = values.a
            }else{
                if result.hasSuffix("@"){
                    result.removeLast()
                }
            }
        }
        
        result = result.removingSuffix(Environment.sipDomain)
        result = result.removingSuffix(Environment.sipDomain)
        
        return result
    }
    
    func splitAtFirst(delimiter: String) -> (a: String, b: String)? {
       guard let upperIndex = (self.range(of: delimiter)?.upperBound), let lowerIndex = (self.range(of: delimiter)?.lowerBound) else { return nil }
       let firstPart: String = .init(self.prefix(upTo: lowerIndex))
       let lastPart: String = .init(self.suffix(from: upperIndex))
       return (firstPart, lastPart)
    }
    
    func indexInt(of char: Character) -> Int? {
        return firstIndex(of: char)?.utf16Offset(in: self)
    }
    
    
    var parseSipUri:String{
        var result = self
        guard let startIndex = indexInt(of: ":"), let endIndex = indexInt(of: "@") else{
            return result
        }
        result = String( result[startIndex+1...endIndex-1] )
        return result
    }
    
    var callInfoDictionaryString:[String]{
        return components(separatedBy: ",")
    }

    var fromUri:String?{
        return self.callInfoDictionaryString.filter({$0.contains("fromUri")}).first?.components(separatedBy: ":").last
    }
    
    var toUri:String?{
        return self.callInfoDictionaryString.filter({$0.contains("toUri")}).first?.components(separatedBy: ":").last
    }
    
    var from:String?{
        return self.callInfoDictionaryString.filter({$0.contains("from")}).first?.components(separatedBy: ":").last
    }
    
    var to:String?{
        return self.callInfoDictionaryString.filter({$0.contains("to")}).first?.components(separatedBy: ":").last
    }
    
    var callType:String?{
        return self.callInfoDictionaryString.filter({$0.contains("type")}).first?.components(separatedBy: ":").last
    }
    
    var callId:String?{
        return self.callInfoDictionaryString.filter({$0.contains("call_id")}).first?.components(separatedBy: ":").last
    }
    
    var isExtraHeadersAvailable :Bool{
        return !self.callInfoDictionaryString.filter({$0.hasPrefix("X-")}).isEmpty
    }
    
    var extraHeaders:[AnyHashable: Any]{
        var result = [AnyHashable: Any]()
        let extraHArray = self.callInfoDictionaryString.filter({$0.hasPrefix("X-")})
       
        for keyValue in extraHArray{
            let keyValueArray = keyValue.components(separatedBy: ":")
            if keyValueArray.first != nil && keyValueArray.last != nil{
                result[keyValueArray.first!] = keyValueArray.last!
            }
        }
        return result
    }
    
    func convertToDictionary() -> [String: Any]? {
        if let data = data(using: .utf8) {
            return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        }
        return nil
    }
    
    func removingPrefix(_ prefix: String) -> String {
        var resultString = self
        if resultString.hasPrefix(prefix.uppercased()) || resultString.hasPrefix(prefix.lowercased()) {
            resultString = resultString.dropFirst(prefix.count).description
        }
        return resultString
    }
    
    var getTerminateState : (party: String,reason: String) {
        let values = self.split(separator: " ")
        return (String(values.first ?? "NULL"),String(values.last ?? "NULL"))
    }
    
    func removingSuffix(_ suffix: String) -> String {
        var resultString = self
        if resultString.hasSuffix(suffix.uppercased()) || resultString.hasSuffix(suffix.lowercased()) {
            resultString = resultString.dropLast(suffix.count).description
        }
        return resultString
    }
    
    var alphanumericString:String{
        return components(separatedBy: CharacterSet.alphanumerics.inverted).joined().trimmingCharacters(in: .whitespaces)
    }
    
    var isAlphanumeric:Bool{
        return self.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil && self != ""
    }
    
    var isNumeric : Bool {
        return CharacterSet(charactersIn: self).isSubset(of: CharacterSet.decimalDigits)
    }
    
}
