//
//  TwitterAPI.swift
//  Justaway
//
//  Created by Shinichiro Aska on 8/14/15.
//  Copyright © 2015 Shinichiro Aska. All rights reserved.
//

import Foundation
import Accounts

public class TwitterAPI {
    public typealias ProgressHandler = (data: NSData) -> Void
    public typealias CompletionHandler = (responseData: NSData?, response: NSURLResponse?, error: NSError?) -> Void
    
    struct Static {
        private static var indicator = true
    }
    
    public class var showIndicator: Bool {
        get { return Static.indicator }
        set { Static.indicator = newValue }
    }
    
    public enum CredentialType {
        case OAuth
        case Account
    }
    
    public class func credential(consumerKey consumerKey: String, consumerSecret: String, accessToken: String, accessTokenSecret: String) -> TwitterAPICredential {
        return TwitterAPI.CredentialOAuth(consumerKey: consumerKey, consumerSecret: consumerSecret, accessToken: accessToken, accessTokenSecret: accessTokenSecret)
    }
    
    public class func credential(account: ACAccount) -> TwitterAPICredential {
        return TwitterAPI.CredentialAccount(account: account)
    }
}
