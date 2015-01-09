import UIKit
import SwifteriOS
import EventBox
import KeyClip

let TIMELINE_ROWS_LIMIT = 1000
let TIMELINE_FOOTER_HEIGHT: CGFloat = 40

class TimelineTableViewController: UITableViewController {
    
    var rows = [TwitterStatus]()
    var rowHeight = [String: CGFloat]()
    var layoutHeight = [TwitterStatusCellLayout: CGFloat]()
    var layoutHeightCell = [TwitterStatusCellLayout: TwitterStatusCell]()
    var lastID: Int64?
    var footerView: UIView?
    var footerIndicatorView: UIActivityIndicatorView?
    var isTop: Bool = true
    var scrolling: Bool = false
    
    enum RenderMode {
        case TOP
        case BOTTOM
        case OVER
    }
    
    struct Static {
        private static let loadDataQueue = NSOperationQueue().serial()
        private static let mainQueue = NSOperationQueue.mainQueue().serial()
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.separatorInset = UIEdgeInsetsZero
        
        let nib = UINib(nibName: "TwitterStatusCell", bundle: nil)
        for layout in TwitterStatusCellLayout.allValues {
            self.tableView.registerNib(nib, forCellReuseIdentifier: layout.rawValue)
            self.layoutHeightCell[layout] = self.tableView.dequeueReusableCellWithIdentifier(layout.rawValue) as? TwitterStatusCell
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if lastID == nil {
            self.loadCache()
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        // EventBox.off(self)
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count ?? 0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let status = rows[indexPath.row]
        let layout = TwitterStatusCellLayout.fromStatus(status)
        let cell = tableView.dequeueReusableCellWithIdentifier(layout.rawValue, forIndexPath: indexPath) as TwitterStatusCell
        
        if let s = cell.status {
            if s.uniqueID == status.uniqueID {
                return cell
            }
        }
        
        cell.status = status
        cell.setLayout(layout)
        cell.setText(status)
        
        ImageLoaderClient.displayUserIcon(status.user.profileImageURL, imageView: cell.iconImageView)
        
        if let actionedBy = status.actionedBy {
            ImageLoaderClient.displayActionedUserIcon(actionedBy.profileImageURL, imageView: cell.actionedIconImageView)
        }
        
        if (!scrolling) {
            cell.setImage(status)
        }
        
        return cell
    }
    
    // MARK: UITableViewDelegate
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let status = rows[indexPath.row]
        return rowHeight[status.uniqueID] ?? 0
    }
    
//    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
//        if indexPath.row >= (rows.count - 1) {
//            didScrollToBottom()
//        }
//    }
    
    override func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return TIMELINE_FOOTER_HEIGHT
    }
    
    override func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if footerView == nil {
            footerView = UIView(frame: CGRectMake(0, 0, view.frame.size.width, TIMELINE_FOOTER_HEIGHT))
            footerIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
            footerView?.addSubview(footerIndicatorView!)
            footerIndicatorView?.hidesWhenStopped = true
            footerIndicatorView?.center = (footerView?.center)!
        }
        return footerView
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    // MARK: UIScrollViewDelegate
    
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if (Static.loadDataQueue.suspended) {
            return
        }
        scrollBegin() // now scrolling
    }
    
    override func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        isTop = false
        scrollBegin() // begin of flick scrolling
    }
    
    override func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if (decelerate) {
            return
        }
        scrollEnd() // end of flick scrolling no deceleration
    }
    
    override func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        scrollEnd() // end of deceleration of flick scrolling
    }
    
    override func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        scrollEnd() // end of setContentOffset
    }
    
    // MARK: Public Methods
    
    func scrollBegin() {
        scrolling = true
        Static.loadDataQueue.suspended = true
        Static.mainQueue.suspended = true
    }
    
    func scrollEnd() {
        scrolling = false
        Static.loadDataQueue.suspended = false
        Static.mainQueue.suspended = false
        isTop = self.tableView.contentOffset.y == 0 ? true : false
        let y = self.tableView.contentOffset.y + self.tableView.bounds.size.height - self.tableView.contentInset.bottom
        let h = self.tableView.contentSize.height
        let f = h - y
        if f < TIMELINE_FOOTER_HEIGHT {
            didScrollToBottom()
        }
        self.renderImages()
    }
    
    func didScrollToBottom() {
        if let maxID = lastID {
            self.loadData(maxID - 1)
        }
    }
    
    func scrollToTop() {
        self.tableView.setContentOffset(CGPointZero, animated: true)
    }
    
    func heightForStatus(status: TwitterStatus, fontSize: CGFloat) -> CGFloat {
        let layout = TwitterStatusCellLayout.fromStatus(status)
        if let height = layoutHeight[layout] {
            return height + heightForText(status.text, fontSize: fontSize) + heightForImage(status)
        } else if let cell = self.layoutHeightCell[layout] {
            cell.frame = self.tableView.bounds
            cell.setText(status)
            cell.setLayout(layout)
            let totalHeight = cell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
            let textHeight = heightForText(status.text, fontSize: fontSize)
            layoutHeight[layout] = totalHeight - textHeight
            return totalHeight + heightForImage(status)
        } else {
            assertionFailure("cellForHeight is missing.")
        }
    }
    
    func heightForText(text: NSString, fontSize: CGFloat) -> CGFloat {
        return text.boundingRectWithSize(
            CGSizeMake((self.layoutHeightCell[.Normal]?.statusLabel.frame.size.width)!, 0),
            options: NSStringDrawingOptions.UsesLineFragmentOrigin,
            attributes: [NSFontAttributeName: UIFont.systemFontOfSize(fontSize)],
            context: nil).size.height
    }
    
    func heightForImage(status: TwitterStatus) -> CGFloat {
        return TwitterStatusCellImagePreviewHeight * CGFloat(status.media.count)
    }
    
    func loadCache() {
        if Static.loadDataQueue.operationCount > 0 {
            println("loadData busy")
            return
        }
        println("loadCache addOperation")
        let op = AsyncBlockOperation({ (op: AsyncBlockOperation) in
            let always: (()-> Void) = {
                op.finish()
                self.footerIndicatorView?.stopAnimating()
            }
            let success = { (statuses: [TwitterStatus]) -> Void in
                self.renderData(statuses, mode: .OVER, handler: always)
            }
            let failure = { (error: NSError) -> Void in
//                println("loadData error: \(error)")
                always()
            }
            dispatch_sync(dispatch_get_main_queue(), {
                self.footerIndicatorView?.startAnimating()
                return
            })
            Twitter.getHomeTimelineCache(success, failure: failure)
        })
        Static.loadDataQueue.addOperation(op)
    }
    
    func saveCache() {
        if self.rows.count > 0 {
            let dictionary = ["statuses": ( self.rows.count > 100 ? Array(self.rows[0 ..< 100]) : self.rows ).map({ $0.dictionaryValue })]
            KeyClip.save("homeTimeline", dictionary: dictionary)
        }
    }
    
    func saveCacheSchedule() {
        Scheduler.regsiter(min: 5, max: 10, target: self, selector: Selector("saveCache"))
    }
    
    func loadData(maxID: Int64?) {
        if Static.loadDataQueue.operationCount > 0 {
            println("loadData busy")
            return
        }
        println("loadData addOperation: \(maxID ?? 0)")
        let op = AsyncBlockOperation({ (op: AsyncBlockOperation) in
            let always: (()-> Void) = {
                op.finish()
                self.footerIndicatorView?.stopAnimating()
            }
            let success = { (statuses: [TwitterStatus]) -> Void in
                
                // Calc cell height for the all statuses
                for status in statuses {
                    let uniqueID = status.uniqueID.longLongValue
                    if (self.lastID == nil || uniqueID < self.lastID!) {
                        self.lastID = uniqueID
                    }
                }
                
                // render statuses
                self.renderData(statuses, mode: (maxID != nil ? .BOTTOM : .OVER), handler: always)
            }
            let failure = { (error: NSError) -> Void in
                println("loadData error: \(error)")
                always()
            }
            dispatch_sync(dispatch_get_main_queue(), {
                self.footerIndicatorView?.startAnimating()
                return
            })
            Twitter.getHomeTimeline(maxID?.stringValue, success: success, failure: failure)
        })
        Static.loadDataQueue.addOperation(op)
    }
    
    func renderData(statuses: [TwitterStatus], mode: RenderMode, handler: (() -> Void)?) {
        
        let fontSize = self.layoutHeightCell[.Normal]?.statusLabel.font.pointSize ?? 12.0
        var insertRowHeight = [String: CGFloat]()
        for status in statuses {
            insertRowHeight[status.uniqueID] = self.heightForStatus(status, fontSize: fontSize)
        }
        
        let op = AsyncBlockOperation { (op) -> Void in
            
            let limit = mode == .OVER ? 0 : TIMELINE_ROWS_LIMIT
            let deleteCount = mode == .OVER ? self.rows.count : max((self.rows.count + statuses.count) - limit, 0)
            let deleteStart = mode == .TOP ? self.rows.count - deleteCount : 0
            let deleteRange = deleteStart ..< (deleteStart + deleteCount)
            let deleteIndexPaths = deleteRange.map { i in NSIndexPath(forRow: i, inSection: 0) }
            let deleteIDs = deleteRange.map { i in self.rows[i].uniqueID }
            
            let insertStart = mode == .BOTTOM ? self.rows.count - deleteCount : 0
            let insertIndexPaths = (insertStart ..< (insertStart + statuses.count)).map { i in NSIndexPath(forRow: i, inSection: 0) }
            
            println("renderData lastID: \(self.lastID ?? 0) insertIndexPaths: \(insertIndexPaths.count) deleteIndexPaths: \(deleteIndexPaths.count) oldRows:\(self.rows.count)")
            
            for key in insertRowHeight.keys {
                self.rowHeight[key] = insertRowHeight[key]
            }
            
            if let lastCell = self.tableView.visibleCells().last as? UITableViewCell {
                
                let offset = lastCell.frame.origin.y - self.tableView.contentOffset.y;
                UIView.setAnimationsEnabled(false)
                self.tableView.beginUpdates()
                if deleteIndexPaths.count > 0 {
                    self.tableView.deleteRowsAtIndexPaths(deleteIndexPaths, withRowAnimation: .None)
                    self.rows.removeRange(deleteRange)
                }
                if insertIndexPaths.count > 0 {
                    var i = 0
                    for insertIndexPath in insertIndexPaths {
                        self.rows.insert(statuses[i], atIndex: insertIndexPath.row)
                        i++
                    }
                    self.tableView.insertRowsAtIndexPaths(insertIndexPaths, withRowAnimation: .None)
                }
                self.tableView.endUpdates()
                self.tableView.setContentOffset(CGPointMake(0, lastCell.frame.origin.y - offset), animated: false)
                UIView.setAnimationsEnabled(true)
                if self.isTop {
                    UIView.animateWithDuration(0.3, animations: { _ in
                        self.tableView.contentOffset = CGPointZero
                    }, completion: { _ in
                        self.renderImages()
                        self.saveCacheSchedule()
                        op.finish()
                    })
                } else {
                    self.saveCacheSchedule()
                    op.finish()
                }
                
            } else {
                if deleteIndexPaths.count > 0 {
                    self.rows.removeRange(deleteRange)
                }
                for status in statuses {
                    self.rows.append(status)
                }
                self.tableView.setContentOffset(CGPointZero, animated: false)
                self.tableView.reloadData()
                self.saveCacheSchedule()
                op.finish()
            }
            
            for key in deleteIDs {
                self.rowHeight.removeValueForKey(key)
            }
            
            if let h = handler {
                h()
            }
        }
        Static.mainQueue.addOperation(op)
    }
    
    func renderImages() {
        for cell in self.tableView.visibleCells() as [TwitterStatusCell] {
            if let status = cell.status {
                cell.setImage(status)
            }
        }
    }
}

private extension String {
    var longLongValue: Int64 {
        return (self as NSString).longLongValue
    }
}

private extension Int64 {
    var stringValue: String {
        return String(self)
    }
}
