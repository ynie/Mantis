//
//  CropViewController.swift
//  Mantis
//
//  Created by Echo on 10/30/18.
//  Copyright © 2018 Echo. All rights reserved.
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

internal class CropViewController: UIViewController {
    public weak var delegate: CropViewControllerDelegate?
    public let config: Mantis.Config
    public let originalImage: UIImage
    
    var cropView: CropView! {
        didSet {
            imageAdjustHelper = ImageAutoAdjustHelper(image: cropView.image)
        }
    }
    private var imageAdjustHelper: ImageAutoAdjustHelper?
    
    private var hasDoneInitialLayout = false
    
    private var hasTransformChanges = false {
        didSet {
            self.updateToolbarItems()
        }
    }
    private var hasImageChanges = false {
        didSet {
            self.updateToolbarItems()
        }
    }
    private var isProcessing = false {
        didSet {
            self.updateToolbarItems()
        }
    }
    private lazy var bottomToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.barStyle = .black
        return toolbar
    }()
    private lazy var spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView()
        spinner.startAnimating()
        return spinner
    }()
    
    deinit {
        print("CropViewController deinit.")
    }

    required public init(config: Mantis.Config, originalImage: UIImage) {
        self.config = config
        self.originalImage = originalImage
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black
        
        cropView.initialSetup(delegate: self, presetFixedRatioType: config.mode.ratioType)
        
        switch config.mode.ratioType {
        case .alwaysUsingOnePresetFixedRatio(let ratio):
            if case .none = config.cropViewConfig.presetTransformationType {
                setFixedRatio(ratio)
            }
                
        case .canUseMultiplePresetFixedRatio(let defaultRatio):
            if defaultRatio > 0 {
                setFixedRatio(defaultRatio)
                cropView.aspectRatioLockEnabled = true
            }
        }
        
        self.updateToolbarItems()
        self.view.addSubview(self.cropView)
        
        if config.mode.isBottomToolBarVisible {
            self.view.addSubview(self.bottomToolbar)
        }
                
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, 
                                                                primaryAction: UIAction { [weak self] _ in
            self?.didTapCancel()
        })
        
        switch self.config.mode {
        case .person:
            self.startPersonCrop()
            
        default:
            self.setupDoneButton()
        }
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let size = self.view.bounds.size
        
        var toolbarHeight: CGFloat = 0
        if config.mode.isBottomToolBarVisible {
            self.bottomToolbar.sizeToFit()
            toolbarHeight = self.view.safeAreaInsets.bottom + self.bottomToolbar.bounds.height
        } else {
            self.bottomToolbar.frame = .zero
        }
        self.bottomToolbar.frame = CGRect(x: 0,
                                          y: size.height - toolbarHeight,
                                          width: size.width,
                                          height: self.bottomToolbar.bounds.height)
        let topPadding = self.view.safeAreaInsets.top
        self.cropView.frame = CGRect(x: 0,
                                     y: topPadding,
                                     width: size.width,
                                     height: self.bottomToolbar.frame.origin.y - topPadding)
        
        self.spinner.sizeToFit()
        let spinnerSize = self.spinner.bounds.size
        self.spinner.frame = CGRect(x: (size.width - spinnerSize.width) / 2.0,
                                    y: (size.height - spinnerSize.height) / 2.0,
                                    width: spinnerSize.width,
                                    height: spinnerSize.height)
        
        if hasDoneInitialLayout == false {
            hasDoneInitialLayout = true
            cropView.resetComponents()
            
            cropView.processPresetTransformation { [weak self] transformation in
                guard let self = self else { return }
                if case .alwaysUsingOnePresetFixedRatio(let ratio) = self.config.mode.ratioType {
                    self.cropView.handlePresetFixedRatio(ratio, transformation: transformation)
                }
            }
        }
    }
    
    public override var prefersStatusBarHidden: Bool {
        return true
    }
    
    public override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.top, .bottom]
    }
    
    // It is triggered by (1) - device rotation or (2) - split view operations on iPad
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        cropView.prepareForViewWillTransition()
        handleViewWillTransition()
    }
    
    @objc func handleViewWillTransition() {
        let currentOrientation = Orientation.interfaceOrientation
        
        guard currentOrientation != .unknown else { return }
        
        if UIDevice.current.userInterfaceIdiom == .phone
            && currentOrientation == .portraitUpsideDown {
            return
        }
                
        // When it is embedded in a container, the timing of viewDidLayoutSubviews
        // is different with the normal mode.
        // So delay the execution to make sure handleRotate runs after the final
        // viewDidLayoutSubviews
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.cropView.handleViewWillTransition()
        }
    }
}

// Auto layout
private extension CropViewController {
    func setupDoneButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done,
                                                                 primaryAction: UIAction { [weak self] _ in
            self?.didTapDone()
        })
    }
    
    func setFixedRatio(_ ratio: Double, zoom: Bool = true) {
        cropView.setFixedRatio(ratio, zoom: zoom, presetFixedRatioType: config.mode.ratioType)
    }
    
    func handleCancel() {
        delegate?.cropViewControllerDidCancel(original: cropView.image)
    }
    
    func isNeedToResetRatioButton() -> Bool {
        var needToResetRatioButton = false
        
        switch config.mode.ratioType {
        case .canUseMultiplePresetFixedRatio(let defaultRatio):
            if defaultRatio == 0 {
                needToResetRatioButton = true
            }
        default:
            break
        }

        return needToResetRatioButton
    }
    
    @objc func handleSetRatio() {
        if cropView.aspectRatioLockEnabled && isNeedToResetRatioButton() {
            return
        }
        
        switch config.mode.ratioType {
        case .alwaysUsingOnePresetFixedRatio(let ratio):
            self.setFixedRatio(ratio)
            
        case .canUseMultiplePresetFixedRatio(let defaultRatio):
            break
        }
    }
    
    func handleAutoAdjust(isActive: Bool) {
        if let angle = imageAdjustHelper?.adjustAngle {
            cropView.reset()
            if isActive {
                cropView.rotate(by: angle)
            }
        }
    }
    
    @objc func didTapReset() {
        self.hasImageChanges = false
        self.hasTransformChanges = false
        
        self.cropView.image = self.originalImage
        self.cropView.reset()
    }
    
    func didTapCancel() {
        self.dismiss(animated: true)
    }
    
    func didTapDone() {
        let spinner = UIActivityIndicatorView()
        spinner.startAnimating()
        spinner.sizeToFit()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        self.navigationItem.leftBarButtonItem = nil
        self.view.isUserInteractionEnabled = false
        
        cropView.asyncCrop { [weak self] cropOutput in
            guard let image = cropOutput.croppedImage else {
                return
            }
            
            self?.delegate?.cropViewControllerDidCrop(cropped: image,
                                                      transformation: cropOutput.transformation,
                                                      cropInfo: cropOutput.cropInfo)
            
            self?.dismiss(animated: true)
        }
    }
    
    func removeBackground() {
        self.isProcessing = true
        
        Task {
            do {
                let image = try await CRPExtractForegroundImage(sourceImage: self.cropView.image)
                await MainActor.run {
                    self.cropView.image = image
                    self.hasImageChanges = true
                }
            } catch {
                let message = "Failed to remove background. \(error.localizedDescription)"
                let alertViewController = UIAlertController(title: "Background Removal Tool",
                                                            message: message,
                                                            preferredStyle: .alert)
                alertViewController.addAction(UIAlertAction(title: "OK", style: .cancel))
                self.present(alertViewController, animated: true)
            }
            await MainActor.run {
                self.isProcessing = false
            }
        }
    }
    
    func trimTransparentPixels() {
        self.isProcessing = true
        
        Task {
            do {
                let image = try await CRPTrimTransparentPixelsInImage(sourceImage: self.cropView.image,
                                                                      targetSize: self.config.mode.size)
                await MainActor.run {
                    self.cropView.image = image
                    self.hasImageChanges = true
                    self.cropView.reset()
                }
            } catch {
                let message = "Failed to trim transparent pixels. \(error.localizedDescription)"
                let alertViewController = UIAlertController(title: "Eraser Tool",
                                                            message: message,
                                                            preferredStyle: .alert)
                alertViewController.addAction(UIAlertAction(title: "OK", style: .cancel))
                self.present(alertViewController, animated: true)
            }
            await MainActor.run {
                self.isProcessing = false
            }
        }
    }
    
    func presentCutOutASubjectController() {
//        let vc = CropSubjectViewControllerViewController(originalImage: self.cropView.image)
//        let nav = UINavigationController(rootViewController: vc)
//        let appearance = UINavigationBarAppearance()
//        appearance.configureWithOpaqueBackground()
//        nav.navigationBar.standardAppearance = appearance
//        nav.overrideUserInterfaceStyle = .dark
//        self.present(nav, animated: true)
    }
    
    func startPersonCrop() {
        self.cropView.isHidden = true
        self.view.addSubview(self.spinner)
        
        Task {
            do {
                let image = try await CRPCropPersonInImage(sourceImage: self.originalImage, targetSize: nil)
                
                await MainActor.run {
                    self.cropView.image = image
                    self.cropView.reset()
                    self.cropView.isHidden = false
                    self.spinner.removeFromSuperview()
                    self.setupDoneButton()
                }
            } catch {
                await MainActor.run {
                    let message = "Failed to crop out the person in the image. \(error.localizedDescription)"
                    let alertViewController = UIAlertController(title: "",
                                                                message: message,
                                                                preferredStyle: .alert)
                    alertViewController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { [weak self] _ in
                        self?.dismiss(animated: true)
                    }))
                    self.present(alertViewController, animated: true)
                }
            }
        }
    }
    
    func updateToolbarItems() {
        let cropMenuItems: [UIAction] = [
            UIAction(title: "Remove Background", image: UIImage(systemName: "person.and.background.dotted"), handler: { [weak self] _ in
                self?.removeBackground()
            }),
            UIAction(title: "Cut Out a Subject", image: UIImage(systemName: "lasso.badge.sparkles"), handler: { [weak self] (_) in
                self?.presentCutOutASubjectController()
            }),
            UIAction(title: "Remove Transparent Pixels", image: UIImage(systemName: "eraser.line.dashed"), handler: { [weak self] _ in
                self?.trimTransparentPixels()
            }),
        ]
        let cropItem = UIBarButtonItem(title: "Crop",
                                       image: UIImage(systemName: "scissors"),
                                       target: nil,
                                       action: nil,
                                       menu: UIMenu(title: "Cropping Tools", children: cropMenuItems))
        
        let resetItem = UIBarButtonItem(title: "Reset",
                                        style: .plain,
                                        target: self,
                                        action: #selector(didTapReset))
        resetItem.isEnabled = (self.isProcessing == false)
        let spinner = UIActivityIndicatorView()
        spinner.startAnimating()
        spinner.sizeToFit()
        let spinnerItem = UIBarButtonItem(customView: spinner)
        
        let flexSpaceItem = UIBarButtonItem(systemItem: .flexibleSpace)
        
        var items: [UIBarButtonItem] = []
        if self.isProcessing {
            items.append(spinnerItem)
        } else {
            items.append(cropItem)
        }
        items.append(flexSpaceItem)
        if self.hasImageChanges || self.hasTransformChanges {
            items.append(resetItem)
        }
        self.bottomToolbar.items = items
    }
}

extension CropViewController: CropViewDelegate {    
    func cropViewDidBecomeResettable(_ cropView: CropView) {
        self.hasTransformChanges = true
    }
    
    func cropViewDidBecomeUnResettable(_ cropView: CropView) {
        self.hasTransformChanges = false
    }
    
    func cropViewDidBeginResize(_ cropView: CropView) {
    }
    
    func cropViewDidEndResize(_ cropView: CropView) {
    }
}
