//
//  Config.swift
//  Mantis
//
//  Created by Echo on 07/07/22.
//  Copyright © 2022 Echo. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import UIKit

// MARK: - Localization
public final class LocalizationConfig {
    public var bundle: Bundle? = Mantis.Config.bundle
    public var tableName = "MantisLocalizable"
}
    
// MARK: - Config
public struct Config {
    public enum Mode {
        case rectangle(size: CGSize)
        case circle(size: CGSize)
        case person(size: CGSize)
        
        public var size: CGSize? {
            switch self {
            case .rectangle(let size):
                return size
                
            case .circle(let size):
                return size
                
            case .person(let size):
                return size
            }
        }
        
        var ratioType: PresetFixedRatioType {
            switch self {
            case .rectangle(let size):
                return .alwaysUsingOnePresetFixedRatio(ratio: size.width / size.height)
                
            case .circle(let size):
                return .alwaysUsingOnePresetFixedRatio(ratio: size.width / size.height)
                
            case .person:
                return .canUseMultiplePresetFixedRatio(defaultRatio: 0)
            }
        }
        
        var isBottomToolBarVisible: Bool {
            switch self {
            case .person:
                return false
                
            default:
                return true
            }
        }
    }
    
    public var cropViewConfig = CropViewConfig()
    public var mode: Mode
    
    static private var bundleIdentifier: String = {
        return "com.echo.framework.Mantis"
    }()

    static private(set) var bundle: Bundle? = {
        guard let bundle = Bundle(identifier: bundleIdentifier) else {
            return nil
        }
        
        guard let url = bundle.url(forResource: "MantisResources", withExtension: "bundle") else {
            return nil
        }
        
        return Bundle(url: url)
    }()
    
    public init(mode: Mode) {
        self.mode = mode
    }
}
