//
//  JiraReader.swift
//  Jiraffe
//
//  Created by Dr. Kerem Koseoglu on 16.07.2020.
//  Copyright © 2020 Dr. Kerem Koseoglu. All rights reserved.
//

import Foundation
import Cocoa

struct Issue: Decodable {
    var id: String
}

struct Reply: Decodable {
    var total: Int
    var issues: [Issue]
}

struct Filter: Decodable {
    var name: String
    var url: String
    var replied: Bool
    var reply: Reply
    var prevReply: Reply
}

struct Filters: Decodable {
    var filters: [Filter]
}

class JiraReader {
    public var newItemCount = 0
    
    private var KUTAPADA_CONFIG = "/Users/Kerem/Dropbox/Apps/kutapada/kutapada.json"
    private var KUTAPADA_KEY = "Ecz - Jira"
    private var JIRAFFE_CONFIG = "/Users/Kerem/Documents/etc/config/jiraffe.json"
    private var filters = Filters(filters: [])
    private var jiraUser = ""
    private var jiraPass = ""
    private var app: NSApplication
    
    init(app: NSApplication) {
        self.app = app
        readJiraffeConfig()
        readKutapadaConfig()
    }
    
    func readJiraffeConfig() {
        do {
            let jsonData = try String(contentsOfFile: JIRAFFE_CONFIG).data(using: .utf8)
            self.filters = try JSONDecoder().decode(Filters.self, from: jsonData!)
        } catch {print(error)}
    }
    
    func readKutapadaConfig() {
        do {
            let jsonData = try String(contentsOfFile: KUTAPADA_CONFIG)
            let pwd = PasswordJsonParser()
            pwd.parseJson(JsonText: jsonData)
            let accounts = pwd.flatAccountList
            
            let key_length = KUTAPADA_KEY.count
            
            for account in accounts {
                if account.name.count >= key_length && account.name.prefix(key_length) == KUTAPADA_KEY {
                    let spl = account.name.components(separatedBy: " - ")
                    self.jiraUser = spl[spl.count-1]
                    self.jiraPass = account.credential
                }
            }
        } catch {print(error)}
    }
    
    func execute() {
        for i in 0..<filters.filters.count {
            filters.filters[i].replied = false
        }
        
        for i in 0..<filters.filters.count {
            executeFilter(filter:filters.filters[i])
        }
    }
    
    func executeFilter(filter: Filter) {
        let url = URL(string: filter.url)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let loginString = String(format: "%@:%@", self.jiraUser, self.jiraPass)
        let loginData = loginString.data(using: String.Encoding.utf8)!
        let base64LoginString = loginData.base64EncodedString()
         
        request.addValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
         
        URLSession.shared.dataTask(with: request) { data, response, error in
           if let data = data {
               do {
                let jiraReply = try JSONDecoder().decode(Reply.self, from: data)
                self.evaluateJiraReply(filter:filter, reply:jiraReply)
               } catch let error {
                  print(error)
               }
            }
        }.resume()
    }
    
    func evaluateJiraReply(filter: Filter, reply: Reply) {
        for curIssue in reply.issues {
            var found = false
            for prevIssue in filter.prevReply.issues {
                if prevIssue.id == curIssue.id {found=true}
            }
            if !found {newItemCount += 1}
        }
        
        for i in 0..<filters.filters.count {
            if filters.filters[i].name == filter.name {
                filters.filters[i].replied = true
                filters.filters[i].prevReply = reply
            }
        }
        
        jiraReplyEvaluationCompleted()
    }
    
    func jiraReplyEvaluationCompleted() {
        for filter in filters.filters {
            if !filter.replied {return}
        }
        if newItemCount > 1 {
            self.app.dockTile.badgeLabel = String(self.newItemCount)
        } else {
            self.app.dockTile.badgeLabel = ""
        }
    }
    
    public func openJira() {
        let randomUrl = self.filters.filters[0].url
        let rootUrl = randomUrl.components(separatedBy: "/rest")[0]
        NSWorkspace.shared.open(URL(string: rootUrl)!)
    }
}