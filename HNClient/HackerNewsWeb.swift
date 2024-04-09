//
//  HackerNewsWeb.swift
//  HNClient
//
//  Created by Myles Linder on 2023-09-07.
//

import Foundation


class Login {
    
    static func vote(path: String) async throws {
        let url = URL(string: "https://news.ycombinator.com/\(path)")!
        let request = URLRequest(url: url)
        if let response = try? await URLSession.shared.data(for: request) {
//            let str = String(decoding: response.0, as: UTF8.self)
//            print(str)
            guard let httpResponse = response.1 as? HTTPURLResponse, httpResponse.statusCode == 200
            else { throw URLError(.badServerResponse) }
            print("SUCCESS!")
        }
    }
    
    static func fetchPage(id: String) async -> String? {
        // TODO: query items?
        print(id)
        let url = URL(string: "https://news.ycombinator.com/item?id=\(id)")!
        let request = URLRequest(url: url)
        if let response = try? await URLSession.shared.data(for: request) {
            let str = String(decoding: response.0, as: UTF8.self)
//            print(str)
            let rgx = try! Regex("(vote\\?id=\(id)&amp;how=up&amp;auth=.{40}&amp;goto=item%3Fid%3D\(id))", as: (Substring, Substring).self)
            if let match = str.firstMatch(of:  rgx) {
                print(match.output)
                let path = String(match.output.1.replacingOccurrences(of: "&amp;", with: "&"))
                print(path)
                try? await Login.vote(path: path)
                return String(match.output.1)
            }
        }
        return .none
    }
    
    
    static func send(username: String, password: String) async {
        let url = URL(string: "https://news.ycombinator.com/login")!
        var components = URLComponents()
        components.queryItems = [
        URLQueryItem(name: "acct", value: "mylesLinder"),
        URLQueryItem(name: "pw", value: "UPDATE_ME"),
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        request.httpBody = components.query!.data(using: .utf8)

        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        let session = URLSession(configuration: config)
//        let a =
        
//        session.dataTask(with: <#T##URLRequest#>)
        if let task = try? await session.data(for: request) {
            let responseData = task.0
            let urlResponse = task.1
            print(responseData)
            let http = urlResponse as! HTTPURLResponse
            let str = String(decoding: responseData, as: UTF8.self)
            print(str)
            print("Login 200", http.statusCode == 200)
        }
    }
}
