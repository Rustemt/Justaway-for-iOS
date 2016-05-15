//
//  TalkViewController.swift
//  Justaway
//
//  Created by Shinichiro Aska on 5/15/16.
//  Copyright © 2016 Shinichiro Aska. All rights reserved.
//

import Foundation
import SwiftyJSON

class TalkViewController: TweetsViewController {

    var rootStatus: TwitterStatus?

    override func loadData() {
        if let status = rootStatus {
            adapter.renderData(tableView, statuses: [status], mode: .BOTTOM, handler: nil)
            if let inReplyToStatusID = status.inReplyToStatusID {
                loadStatus(inReplyToStatusID)
            }
            searchStatus(status)
        }
    }

    func loadStatus(statusID: String) {
        let success = { (statuses: [TwitterStatus]) -> Void in
            self.adapter.renderData(self.tableView, statuses: statuses, mode: .TOP, handler: nil)
            for status in statuses {
                if let inReplyToStatusID = status.inReplyToStatusID {
                    self.loadStatus(inReplyToStatusID)
                }
            }
        }
        let failure = { (error: NSError) -> Void in
            ErrorAlert.show("Error", message: error.localizedDescription)
        }
        Twitter.getStatuses([statusID], success: success, failure: failure)
    }

    func searchStatus(sourceStatus: TwitterStatus) {
        var allStatuses = [TwitterStatus]()
        var isReplyIDs = [String: Bool]()
        isReplyIDs[sourceStatus.statusID] = true
        let lookupAlways = {

            let replies =
                allStatuses
                    .sort { $0.0.statusID.longLongValue < $0.1.statusID.longLongValue }
                    .filter { status in
                        // NSLog("\(status.statusID.longLongValue) \(status.createdAt.absoluteString) \(status.text)")
                        if let inReplyToStatusID = status.inReplyToStatusID where isReplyIDs[inReplyToStatusID] != nil {
                            isReplyIDs[status.statusID] = true
                            return true
                        } else {
                            return false
                        }
            }
            if replies.count > 0 {
                self.adapter.renderData(self.tableView, statuses: replies, mode: .BOTTOM, handler: nil)
            }
        }
        let lookupSuccess = { (statuses: [TwitterStatus]) in
            allStatuses += statuses
            lookupAlways()
        }
        let lookupFailure = { (error: NSError) in
            lookupAlways()
        }
        let fromAlways = {
            var loadIDs = [String: Bool]()
            for status in allStatuses {
                loadIDs[status.statusID] = true
            }
            var lookupIDs = [String]()
            for status in allStatuses {
                if let inReplyToStatusID = status.inReplyToStatusID where loadIDs[inReplyToStatusID] == nil {
                    loadIDs[inReplyToStatusID] = true
                    lookupIDs.append(inReplyToStatusID)
                    if lookupIDs.count >= 100 {
                        break
                    }
                }
            }
            if lookupIDs.count > 0 {
                Twitter.getStatuses(lookupIDs, success: lookupSuccess, failure: lookupFailure)
            } else {
                lookupAlways()
            }
        }
        let fromSuccess = { (statuses: [TwitterStatus], searchMetadata: [String: JSON]) in
            allStatuses += statuses
            fromAlways()
        }
        let fromFailure = { (error: NSError) in
            fromAlways()
        }
        let fromQuery = "from:\(sourceStatus.user.screenName) AND filter:replies"
        let toAlways = {
            Twitter.getSearchTweets(fromQuery, maxID: nil, sinceID: sourceStatus.statusID, excludeRetweets: true, success: fromSuccess, failure: fromFailure)
        }
        let toSuccess = { (statuses: [TwitterStatus], searchMetadata: [String: JSON]) in
            allStatuses += statuses
            toAlways()
        }
        let toFailure = { (error: NSError) in
            toAlways()
        }
        let toQuery = "to:\(sourceStatus.user.screenName) AND filter:replies"
        Twitter.getSearchTweets(toQuery, maxID: nil, sinceID: sourceStatus.statusID, excludeRetweets: true, success: toSuccess, failure: toFailure)
    }

    // MARK: - Class Methods

    class func show(status: TwitterStatus) {
        let instance = TalkViewController()
        instance.rootStatus = TwitterStatus(status, type: .Normal, event: nil, actionedBy: nil)
        ViewTools.slideIn(instance)
    }
}
