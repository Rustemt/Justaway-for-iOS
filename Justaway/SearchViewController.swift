//
//  SearchViewController.swift
//  Justaway
//
//  Created by Shinichiro Aska on 9/29/15.
//  Copyright © 2015 Shinichiro Aska. All rights reserved.
//

import UIKit
import SwiftyJSON
import Async
import EventBox

class SearchViewController: UIViewController {

    // MARK: Properties

    let refreshControl = UIRefreshControl()
    let adapter = TwitterStatusAdapter()
    let keywordAdapter = SearchKeywordAdapter()
    var keywordStreaming: TwitterSearchStreaming?
    let userAdapter = TwitterUserAdapter()
    var nextResults: String?
    var nextPage: Int?
    var keyword: String?
    var excludeRetweets = true

    @IBOutlet weak var tweetsTableView: UITableView!
    @IBOutlet weak var usersTableView: UITableView!
    @IBOutlet weak var keywordTableView: UITableView!
    @IBOutlet weak var keywordTextField: UITextField!
    @IBOutlet weak var streamingButton: UIButton!
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    override var nibName: String {
        return "SearchViewController"
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        configureEvent()
        keywordTextField.text = keyword
        if let keyword = keyword where !keyword.isEmpty {
            keywordTextField.rightViewMode = .Always
            loadData()
            keywordAdapter.appendHistory(keyword, tableView: keywordTableView)
            streamingButton.enabled = true
        } else {
            keywordTextField.becomeFirstResponder()
            keywordTextField.rightViewMode = .Never
            keywordTableView.hidden = false
            streamingButton.enabled = false
        }
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        EventBox.off(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for c in tweetsTableView.visibleCells {
            if let cell = c as? TwitterStatusCell {
                cell.statusLabel.setAttributes()
            }
        }

    }

    // MARK: - Configuration

    func configureView() {
        refreshControl.addTarget(self, action: #selector(loadDataToTop), forControlEvents: UIControlEvents.ValueChanged)
        tweetsTableView.addSubview(refreshControl)

        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(hide))
        swipe.numberOfTouchesRequired = 1
        swipe.direction = .Right
        tweetsTableView.panGestureRecognizer.requireGestureRecognizerToFail(swipe)
        tweetsTableView.addGestureRecognizer(swipe)

        adapter.configureView(nil, tableView: tweetsTableView)
        adapter.didScrollToBottom = {
            if let nextResults = self.nextResults {
                if let queryItems = NSURLComponents(string: nextResults)?.queryItems {
                    for item in queryItems {
                        if item.name == "max_id" {
                            self.loadData(item.value)
                            break
                        }
                    }
                }
            }
        }

        userAdapter.configureView(usersTableView)
        userAdapter.didScrollToBottom = {
            if let nextPage = self.nextPage {
                self.nextPage = nil
                self.loadUserData(nextPage)
            }
        }

        usersTableView.panGestureRecognizer.requireGestureRecognizerToFail(swipe)
        usersTableView.addGestureRecognizer(swipe)

        let button = MenuButton()
        button.tintColor = UIColor.clearColor()
        button.titleLabel?.font = UIFont(name: "fontello", size: 16.0)
        button.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignment.Center
        button.contentVerticalAlignment = UIControlContentVerticalAlignment.Center
        button.setTitle("✖", forState: UIControlState.Normal)
        button.addTarget(self, action: #selector(clear), forControlEvents: .TouchUpInside)
        keywordTextField.addTarget(self, action: #selector(change), forControlEvents: .EditingChanged)
        keywordTextField.rightView = button
        keywordTextField.rightViewMode = .Always

        keywordAdapter.configureView(keywordTableView)
        keywordAdapter.selectCallback = { [weak self] (keyword) -> Void in
            guard let `self` = self else {
                return
            }
            self.keywordAdapter.appendHistory(keyword, tableView: self.keywordTableView)
            self.keywordTextField.text = keyword
            self.keyword = keyword
            self.loadData()
            self.keywordTextField.resignFirstResponder()
        }
        keywordAdapter.scrollCallback = { [weak self] in
            self?.keywordTextField.resignFirstResponder()
        }

        streamingButton.setTitleColor(ThemeController.currentTheme.bodyTextColor(), forState: .Normal)
    }

    func loadData(maxID: String? = nil) {
        guard let keyword = keyword else {
            return
        }
        if keyword.isEmpty {
            return
        }
        keywordTableView.hidden = true
        if segmentedControl.selectedSegmentIndex > 1 {
            tweetsTableView.hidden = true
            usersTableView.hidden = false
            loadUserData()
            return
        }
        tweetsTableView.hidden = false
        usersTableView.hidden = true
        let op = AsyncBlockOperation({ (op: AsyncBlockOperation) in
            let always: (Void -> Void) = {
                op.finish()
                self.adapter.footerIndicatorView?.stopAnimating()
                self.refreshControl.endRefreshing()
            }
            let success = { (statuses: [TwitterStatus], search_metadata: [String: JSON]) -> Void in

                self.nextResults = search_metadata["next_results"]?.string
                self.renderData(statuses, mode: (maxID != nil ? .BOTTOM : .OVER), handler: always)
            }
            let failure = { (error: NSError) -> Void in
                ErrorAlert.show("Error", message: error.localizedDescription)
                always()
            }
            if !self.refreshControl.refreshing {
                Async.main {
                    self.adapter.footerIndicatorView?.startAnimating()
                    return
                }
            }
            let resultType = self.segmentedControl.selectedSegmentIndex == 0 ? "recent" : "popular"
            Twitter.getSearchTweets(keyword, maxID: maxID, sinceID: nil, excludeRetweets: self.excludeRetweets, resultType: resultType, success: success, failure: failure)
        })
        self.adapter.loadDataQueue.addOperation(op)
    }

    func loadDataToTop() {
        if AccountSettingsStore.get() == nil {
            return
        }

        if self.adapter.rows.count == 0 {
            loadData()
            return
        }

        if self.adapter.loadDataQueue.operationCount > 0 {
            NSLog("loadDataToTop busy")
            return
        }

        if segmentedControl.selectedSegmentIndex > 1 {
            return
        }

        NSLog("loadDataToTop addOperation: suspended:\(self.adapter.loadDataQueue.suspended)")
        guard let keyword = keyword else {
            return
        }
        let op = AsyncBlockOperation({ (op: AsyncBlockOperation) in
            let always: (Void -> Void) = {
                op.finish()
                self.refreshControl.endRefreshing()
            }
            let success = { (statuses: [TwitterStatus], search_metadata: [String: JSON]) -> Void in

                // render statuses
                self.renderData(statuses, mode: .HEADER, handler: always)
            }
            let failure = { (error: NSError) -> Void in
                ErrorAlert.show("Error", message: error.localizedDescription)
                always()
            }
            if let sinceID = self.adapter.sinceID() {
                NSLog("loadDataToTop load sinceID:\(sinceID)")
                let resultType = self.segmentedControl.selectedSegmentIndex == 0 ? "recent" : "popular"
                Twitter.getSearchTweets(keyword, maxID: nil, sinceID: (sinceID.longLongValue - 1).stringValue, excludeRetweets: self.excludeRetweets, resultType: resultType, success: success, failure: failure)
            } else {
                op.finish()
            }
        })
        self.adapter.loadDataQueue.addOperation(op)
    }

    func renderData(statuses: [TwitterStatus], mode: TwitterStatusAdapter.RenderMode, handler: (() -> Void)?) {
        let operation = MainBlockOperation { (operation) -> Void in
            self.adapter.renderData(self.tweetsTableView, statuses: statuses, mode: mode, handler: { () -> Void in
                if self.adapter.isTop {
                    self.adapter.scrollEnd(self.tweetsTableView)
                }
                operation.finish()
            })

            if let h = handler {
                h()
            }
        }
        self.adapter.mainQueue.addOperation(operation)
    }

    func loadUserData(page: Int = 1) {
        guard let keyword = keyword else {
            return
        }
        if keyword.isEmpty {
            return
        }
        keywordTableView.hidden = true
        let op = AsyncBlockOperation({ (op: AsyncBlockOperation) in
            let always: (Void -> Void) = {
                op.finish()
                self.userAdapter.footerIndicatorView?.stopAnimating()
                self.refreshControl.endRefreshing()
            }
            let success = { (users: [TwitterUserFull]) -> Void in
                if users.count > 0 {
                    self.nextPage = page + 1
                }
                self.renderUserData(users, mode: (page > 1 ? .BOTTOM : .OVER), handler: always)
            }
            let failure = { (error: NSError) -> Void in
                ErrorAlert.show("Error", message: error.localizedDescription)
                always()
            }
            if !self.refreshControl.refreshing {
                Async.main {
                    self.userAdapter.footerIndicatorView?.startAnimating()
                    return
                }
            }
            Twitter.getUsers(keyword, page: page, success: success, failure: failure)
        })
        self.userAdapter.loadDataQueue.addOperation(op)
    }

    func renderUserData(users: [TwitterUserFull], mode: TwitterStatusAdapter.RenderMode, handler: (() -> Void)?) {
        let operation = MainBlockOperation { (operation) -> Void in
            self.userAdapter.renderData(self.usersTableView, users: users, mode: mode, handler: { () -> Void in
//                if self.userAdapter.isTop {
//                    self.userAdapter.scrollEnd(self.tweetsTableView)
//                }
                operation.finish()
            })

            if let h = handler {
                h()
            }
        }
        self.userAdapter.mainQueue.addOperation(operation)
    }

    func configureEvent() {
        EventBox.onMainThread(self, name: eventStatusBarTouched, handler: { (n) -> Void in
            self.adapter.scrollToTop(self.tweetsTableView)
        })
        EventBox.onMainThread(self, name: UIKeyboardWillShowNotification) { n in
            self.keyboardWillChangeFrame(n, showsKeyboard: true)
        }

        EventBox.onMainThread(self, name: UIKeyboardWillHideNotification) { n in
            self.keyboardWillChangeFrame(n, showsKeyboard: false)
        }
        configureCreateStatusEvent()
        configureDestroyStatusEvent()
    }

    func configureCreateStatusEvent() {
        EventBox.onMainThread(self, name: Twitter.Event.CreateStatus.rawValue, sender: nil) { n in
            guard let status = n.object as? TwitterStatus else {
                return
            }
            guard let keyword = self.keyword else {
                return
            }
            if status.text.containsString(keyword) {
                self.renderData([status], mode: .TOP, handler: {})
            }
        }
    }

    func configureDestroyStatusEvent() {
        EventBox.onMainThread(self, name: Twitter.Event.DestroyStatus.rawValue, sender: nil) { n in
            guard let statusID = n.object as? String else {
                return
            }
            let operation = MainBlockOperation { (operation) -> Void in
                self.adapter.eraseData(self.tweetsTableView, statusID: statusID, handler: { () -> Void in
                    operation.finish()
                })
            }
            self.adapter.mainQueue.addOperation(operation)
        }
    }

    // MARK: - Actions

    func keyboardWillChangeFrame(notification: NSNotification, showsKeyboard: Bool) {
        if showsKeyboard {
            keywordTableView.hidden = false
            keywordAdapter.loadData(keywordTableView)
        }
        change()
    }

    @IBAction func menu(sender: UIView) {
        if keywordTextField.isFirstResponder() {
            keywordTextField.resignFirstResponder()
            return
        }
        guard let keyword = keywordTextField.text else {
            return
        }
        if keyword.isEmpty {
            MessageAlert.show("Please input keyword")
            return
        }
        if segmentedControl.selectedSegmentIndex > 1 {
            return
        }
        showMenu(sender, keyword: keyword)
    }

    @IBAction func streaming(sender: AnyObject) {
        if let status = keywordStreaming?.status where status == .CONNECTED || status == .CONNECTING {
            let alert = UIAlertController(title: "Disconnect search streaming?", message: nil, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { [weak self] action in
                self?.keywordStreaming?.stop()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            AlertController.showViewController(alert)
            return
        }
        guard let keyword = self.keyword where !keyword.isEmpty else {
            return
        }
        if segmentedControl.selectedSegmentIndex > 1 {
            return
        }
        let alert = UIAlertController(title: "Connect search streaming?", message: nil, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { [weak self] action in
            guard let `self` = self else {
                return
            }
            guard let account = AccountSettingsStore.get()?.account() else {
                return
            }
            self.keywordStreaming = TwitterSearchStreaming(
                account: account,
                receiveStatus: self.receiveStatus,
                connected: self.connectStreaming,
                disconnected: self.disconnectStreaming).start(keyword)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        AlertController.showViewController(alert)
    }

    @IBAction func search(sender: AnyObject) {
        guard let keyword = keywordTextField.text else {
            NSLog("no data")
            return
        }
        if keyword.isEmpty {
            NSLog("empty")
            return
        }
        NSLog("search")
        self.keyword = keyword
        loadData()
        keywordAdapter.appendHistory(keyword, tableView: keywordTableView)
    }

    @IBAction func left(sender: UIButton) {
        if keywordTextField.isFirstResponder() {
            keywordTextField.resignFirstResponder()
        }
        hide()
    }

    @IBAction func post(sender: AnyObject) {
        guard let keyword = keyword else {
            return
        }
        EditorViewController.show(" " + keyword, range: NSRange(location: 0, length: 0), inReplyToStatus: nil)
    }

    @IBAction func segmentedChange(sender: AnyObject) {

    }

    func clear() {
        keywordTextField.text = ""
        keywordTextField.rightViewMode = .Never
    }

    func change() {
        if keywordTextField.text?.isEmpty ?? true {
            keywordTextField.rightViewMode = .Never
            streamingButton.enabled = false
        } else {
            keywordTextField.rightViewMode = .Always
            streamingButton.enabled = true
        }
    }

    func hide() {
        keywordStreaming?.stop()
        ViewTools.slideOut(self)
    }

    // MARK: - TwitterSearchStreaming


    func receiveStatus(status: TwitterStatus) {
        if excludeRetweets && status.actionedBy != nil {
            return
        }
        adapter.renderData(tweetsTableView, statuses: [status], mode: .TOP, handler: nil)
    }

    func connectStreaming() {
        streamingButton.setTitleColor(ThemeController.currentTheme.streamingConnected(), forState: .Normal)
    }

    func disconnectStreaming() {
        streamingButton.setTitleColor(ThemeController.currentTheme.bodyTextColor(), forState: .Normal)
    }

    // MARK: - Class Methods

    class func show(keyword: String) {
        let instance = SearchViewController()
        instance.keyword = keyword
        ViewTools.slideIn(instance)
    }
}
