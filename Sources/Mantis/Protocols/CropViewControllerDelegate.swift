//
//  CropViewControllerDelegate.swift
//  Mantis
//
//  Created by yingtguo on 1/20/23.
//

import UIKit

public protocol CropViewControllerDelegate: AnyObject {
    func cropViewControllerDidCrop(cropped: UIImage,
                                   transformation: Transformation,
                                   cropInfo: CropInfo)
    func cropViewControllerDidCancel(original: UIImage)
}

