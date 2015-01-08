//
//  ThemeLight.swift
//  Justaway
//
//  Created by Shinichiro Aska on 1/9/15.
//  Copyright (c) 2015 Shinichiro Aska. All rights reserved.
//

import UIKit

class ThemeLight: Theme {
    func statusBarStyle() -> UIStatusBarStyle { return UIStatusBarStyle.Default }
    
    func mainBackgroundColor() -> UIColor { return UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1) }
    func mainHighlightBackgroundColor() -> UIColor { return UIColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1) }
    func titleTextColor() -> UIColor { return UIColor.darkGrayColor() }
    func bodyTextColor() -> UIColor { return UIColor.darkGrayColor() }
    
    func displayNameTextColor() -> UIColor { return UIColor.darkGrayColor() }
    func screenNameTextColor() -> UIColor { return UIColor.lightGrayColor() }
    func relativeDateTextColor() -> UIColor { return UIColor.lightGrayColor() }
    func absoluteDateTextColor() -> UIColor { return UIColor.lightGrayColor() }
    func clientNameTextColor() -> UIColor { return UIColor.lightGrayColor() }
    
    func menuBackgroundColor() -> UIColor { return UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1) }
    func menuTextColor() -> UIColor { return UIColor.darkGrayColor() }
    func menuHighlightTextColor() -> UIColor { return ThemeColor.Holo.blueDark }
    func menuDisabledTextColor() -> UIColor { return UIColor.grayColor() }
    
    func buttonNormal() -> UIColor { return UIColor.lightGrayColor() }
    func retweetButtonSelected() -> UIColor { return ThemeColor.Holo.greenDark }
    func favoritesButtonSelected() -> UIColor { return ThemeColor.Holo.orangeDark }

}