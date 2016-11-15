//
//  AlgoDataDirectory.swift
//  Algorithmia
//
//  Created by Erik Ilyin on 11/11/16.
//  Copyright © 2016 algorithmia. All rights reserved.
//

import Foundation

typealias AlgoDataListingHandler = ( AlgoDataObject?) -> Void

class AlgoDirectory:AlgoDataObject {
    init(client: AlgoAPIClient, dataUrl: String) {
        super.init(client: client, dataUrl: dataUrl, type: .Directory)
    }
    
    func forEach(_ object:@escaping AlgoDataListingHandler, completion:@escaping AlgoSimpleCompletionHandler) -> AlgoDataListing {
        let listing = AlgoDataListing(client: client, path: getUrl())
        listing.incFile = true
        listing.incDir = true
        listing.forEach(handler: object, completion: completion)
        return listing
    }
    
    func forEach(dir:@escaping (AlgoDirectory?) -> Void, completion:@escaping AlgoSimpleCompletionHandler) -> AlgoDataListing {
        let listing = AlgoDataListing(client: client, path: getUrl())
        listing.incFile = false
        listing.incDir = true
        listing.forEach(handler: { (dataObject) in
            dir(dataObject as? AlgoDirectory)
            }, completion: completion)
        return listing
    }
    
    func forEach(file:@escaping (AlgoDataFile?) -> Void, completion:@escaping AlgoSimpleCompletionHandler) -> AlgoDataListing {
        let listing = AlgoDataListing(client: client, path: getUrl())
        listing.incFile = true
        listing.incDir = false
        listing.forEach(handler: { (dataObject) in
            file(dataObject as? AlgoDataFile)
            }, completion: completion)
        return listing
    }
    
    
}

class AlgoDataListing {
    var client: AlgoAPIClient
    var path: String
    var page:[String:Any]?
    var marker: String?
    var handler: AlgoDataListingHandler?
    var incFile: Bool
    var incDir: Bool
    init(client: AlgoAPIClient, path: String) {
        self.client = client;
        self.path = path;
        incFile = false;
        incDir = false;
    }
    
    func forEach(handler: @escaping AlgoDataListingHandler, completion: @escaping AlgoSimpleCompletionHandler ) {
        self.handler = handler
        self.loadNextPage(completion: completion)
    }
    
    func loadNextPage(completion: @escaping AlgoSimpleCompletionHandler) {
        var options = [String:String]()
        if marker != nil {
            options["marker"] = marker
        }
        _ = client.send(method: .GET, path: path, data: AlgoStringEntity(entity:""), options: options) { (respData, error) in
            if error != nil {
                completion(error)
            }
            else if respData.statusCode != 200 {
                completion(AlgoError.DataError("Error code:%@"))
            }
            else {
                do {
                    try self.page = respData.getJSON()
                    if self.incFile {
                        if let fileArray = self.page?["files"] as? [Any] {
                            for obj in fileArray {
                                if let file = obj as? [String:Any] {
                                    let path = self.path + (file["filename"] as! String)
                                    let dataFile = AlgoDataFile(client: self.client, dataUrl: path)
                                    self.handler?(dataFile)
                                }
                            }
                        }
                    }
                    
                    if self.incDir {
                        if let dirArray = self.page?["files"] as? [Any] {
                            for obj in dirArray {
                                if let dir = obj as? [String:Any] {
                                    let path = self.path + (dir["filename"] as! String)
                                    let dataDir = AlgoDirectory(client: self.client, dataUrl: path)
                                    self.handler?(dataDir)
                                }
                            }
                        }
                    }
                    
                    if let marker = self.page?["marker"] as? String {
                        self.marker = marker
                        self.loadNextPage(completion: completion)
                        return;
                    }
                    
                    completion(error)
                } catch  {
                    completion(AlgoError.DataError("Invalid JSON response"))
                }
            }
        }
    }
}


