//
//  TabSettingsCell.swift
//  Justaway
//
//  Created by Shinichiro Aska on 2/6/16.
//  Copyright © 2016 Shinichiro Aska. All rights reserved.
//

import UIKit

class TabSettingsCell: BackgroundTableViewCell {

    @IBOutlet weak var iconLabel: TextLable!
    @IBOutlet weak var nameLabel: TextLable!

    // MARK: - View Life Cycle

    override func awakeFromNib() {
        super.awakeFromNib()
        configureView()
    }

    // MARK: - Configuration

    func configureView() {
        selectionStyle = .None
        separatorInset = UIEdgeInsetsZero
        layoutMargins = UIEdgeInsetsZero
        preservesSuperviewLayoutMargins = false
    }
}
