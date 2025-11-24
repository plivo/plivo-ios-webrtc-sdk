//
//  HTTPCLient.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 27/04/21.
//

import Foundation

struct StringError : LocalizedError {
    public let errorDescription: String?
}

class HTTPClient {

    static let shared = HTTPClient()

    private init(){
        LogManager.shared.log("init HTTPClient", level: .notice)
    }

    deinit {
        LogManager.shared.log("deinit HTTPClient", level: .notice)
    }

    public typealias ResultCallback<Value> = (Result<Value, Error>) -> Void

    func postRequest(url:URL?, params:[String:String], completion: @escaping ResultCallback<Any>){

        guard let serviceUrl = url else {
            completion(.failure(StringError(errorDescription: "Bad URL")))
            return
        }

        var request = URLRequest(url: serviceUrl)
        request.httpMethod = "POST"

        guard let httpBody = try? JSONEncoder().encode(params) else {
            completion(.failure(StringError(errorDescription: "Bad Parameters")))
            return
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(httpBody.count)", forHTTPHeaderField: "Content-length")
        request.setValue(serviceUrl.host, forHTTPHeaderField: "Host")

        request.httpBody = httpBody

        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let response = response {
                print("DUMP",response.description)
            }
            if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                    completion(.success(json))
                    LogManager.shared.log("HTTP POST call success : \(json)", level: .info)
                } catch {
                    completion(.failure(error))
                    LogManager.shared.log("HTTP POST call failied : \(error.localizedDescription)", level: .error)
                }
            }
        }.resume()
    }

    func putRequest(urlString:String, params:[String:String], completion: @escaping ResultCallback<Any>){

//        print("HTTP PUT",urlString,params)

        guard let serviceUrl = URL(string: urlString) else {
            completion(.failure(StringError(errorDescription: "Bad URL")))
            return
        }

        var request = URLRequest(url: serviceUrl, timeoutInterval: 30.0)
        request.httpMethod = "PUT"

        guard let httpBody = try? JSONEncoder().encode(params) else {
            completion(.failure(StringError(errorDescription: "Bad Parameters")))
            return
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(httpBody.count)", forHTTPHeaderField: "Content-length")
        request.setValue(serviceUrl.host, forHTTPHeaderField: "Host")

        request.httpBody = httpBody

        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let response = response {
                print("HTTP PUT",response)
            }
            if let httpResponse = response as? HTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    completion(.success("Success"))
                    LogManager.shared.log("HTTP PUT call success", level: .info)
                }else{
                    completion(.failure(StringError(errorDescription: "HTTP Call failed \(httpResponse.statusCode)")))
                    LogManager.shared.log("HTTP Call failed \(httpResponse.statusCode)", level: .error)
                }
            }
        }.resume()

    }

}
