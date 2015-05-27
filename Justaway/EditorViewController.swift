import UIKit
import EventBox
import QBImagePicker

class EditorViewController: UIViewController, QBImagePickerControllerDelegate {
    
    // MARK: Properties
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var containerViewButtomConstraint: NSLayoutConstraint! // Used to adjust the height when the keyboard hides and shows.
    
    @IBOutlet weak var textView: AutoExpandTextView!
    @IBOutlet weak var textViewHeightConstraint: NSLayoutConstraint! // Used to AutoExpandTextView
    
    let imagePickerController = QBImagePickerController.new()
    
    override var nibName: String {
        return "EditorViewController"
    }
    
    var inReplyToStatusId: String?
    
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
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        EventBox.off(self)
    }
    
    // MARK: - Configuration
    
    func configureView() {
        textView.configure(heightConstraint: textViewHeightConstraint)
        
        imagePickerController.delegate = self
        imagePickerController.allowsMultipleSelection = true
        imagePickerController.maximumNumberOfSelection = 6
        imagePickerController.showsNumberOfSelectedAssets = true
    }
    
    func configureEvent() {
        EventBox.onMainThread(self, name: UIKeyboardWillShowNotification) { n in
            if self.view.hidden == false {
                self.keyboardWillChangeFrame(n, showsKeyboard: true)
            }
        }
        
        EventBox.onMainThread(self, name: UIKeyboardWillHideNotification) { n in
            if self.view.hidden == false {
                self.keyboardWillChangeFrame(n, showsKeyboard: false)
            }
        }
    }
    
    // MARK: - Keyboard Event Notifications
    
    func keyboardWillChangeFrame(notification: NSNotification, showsKeyboard: Bool) {
        let userInfo = notification.userInfo!
        let animationDuration: NSTimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let keyboardScreenEndFrame = (userInfo[UIKeyboardFrameEndUserInfoKey]as! NSValue).CGRectValue()
        
        if showsKeyboard {
            let orientation: UIInterfaceOrientation = UIApplication.sharedApplication().statusBarOrientation
            if (orientation.isLandscape) {
                containerViewButtomConstraint.constant = keyboardScreenEndFrame.size.width
            } else {
                containerViewButtomConstraint.constant = keyboardScreenEndFrame.size.height
            }
        } else {
            containerViewButtomConstraint.constant = 0
        }
        
        self.view.setNeedsUpdateConstraints()
        
        UIView.animateWithDuration(animationDuration, delay: 0, options: .BeginFromCurrentState, animations: {
            self.containerView.alpha = showsKeyboard ? 1 : 0
            self.view.layoutIfNeeded()
        }, completion: { finished in
            if !showsKeyboard {
                self.view.hidden = true
            }
        })
    }
    
    // MARK: - Actions
    
    @IBAction func hide(sender: UIButton) {
        hide()
    }
    
    @IBAction func image(sender: UIButton) {
        self.view.window?.rootViewController?.presentViewController(imagePickerController, animated: true, completion: nil)
    }
    
    @IBAction func send(sender: UIButton) {
        let text = textView.text
        if text.isEmpty {
            hide()
        } else {
            Twitter.statusUpdate(text, inReplyToStatusID: inReplyToStatusId)
            hide()
        }
        
    }
    
    func show() {
        view.hidden = false
        textView.becomeFirstResponder()
    }
    
    func hide() {
        textView.reset()
        inReplyToStatusId = nil
        
        if (textView.isFirstResponder()) {
            textView.resignFirstResponder()
        } else {
            view.hidden = true
        }
    }
    
}
