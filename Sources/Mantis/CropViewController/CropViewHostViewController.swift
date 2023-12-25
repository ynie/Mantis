//
//  CropViewHostViewController.swift
//
//
//  Created by Steven Nie on 12/25/23.
//

import Foundation
import UIKit

public class CropViewHostViewController: UINavigationController {
    public init(image: UIImage, config: Mantis.Config, delegate: CropViewControllerDelegate) {
        let cropViewController = CropViewController(config: config, originalImage: image)
        cropViewController.cropView = CropViewHostViewController.buildCropView(withImage: image,
                                                                               config: config.cropViewConfig,
                                                                               rotationControlView: nil)
        cropViewController.delegate = delegate
        super.init(rootViewController: cropViewController)
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        self.navigationBar.standardAppearance = appearance
        self.overrideUserInterfaceStyle = .dark
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension CropViewHostViewController {
    static func buildCropView(withImage image: UIImage,
                              config cropViewConfig: CropViewConfig,
                              rotationControlView: RotationControlViewProtocol?) -> CropView {
        let cropAuxiliaryIndicatorView = CropAuxiliaryIndicatorView(frame: .zero,
                                                                    cropBoxHotAreaUnit: cropViewConfig.cropBoxHotAreaUnit,
                                                                    disableCropBoxDeformation: cropViewConfig.disableCropBoxDeformation)
        let imageContainer = ImageContainer(image: image)
        let cropView = CropView(image: image,
                                cropViewConfig: cropViewConfig,
                                viewModel: buildCropViewModel(with: cropViewConfig),
                                cropAuxiliaryIndicatorView: cropAuxiliaryIndicatorView,
                                imageContainer: imageContainer,
                                cropWorkbenchView: buildCropWorkbenchView(with: cropViewConfig, and: imageContainer),
                                cropMaskViewManager: buildCropMaskViewManager(with: cropViewConfig))
        
        setupRotationControlViewIfNeeded(withConfig: cropViewConfig, cropView: cropView, rotationControlView: rotationControlView)
        return cropView
    }
    
    static func buildCropViewModel(with cropViewConfig: CropViewConfig) -> CropViewModelProtocol {
        CropViewModel(
            cropViewPadding: cropViewConfig.padding,
            hotAreaUnit: cropViewConfig.cropBoxHotAreaUnit
        )
    }
    
    static func buildCropWorkbenchView(with cropViewConfig: CropViewConfig, and imageContainer: ImageContainerProtocol) -> CropWorkbenchViewProtocol {
        CropWorkbenchView(frame: .zero,
                          minimumZoomScale: cropViewConfig.minimumZoomScale,
                          maximumZoomScale: cropViewConfig.maximumZoomScale,
                          imageContainer: imageContainer)
    }
    
    static func buildCropMaskViewManager(with cropViewConfig: CropViewConfig) -> CropMaskViewManagerProtocol {
        let dimmingView = CropDimmingView(cropShapeType: cropViewConfig.cropShapeType)
        let visualEffectView = CropMaskVisualEffectView(cropShapeType: cropViewConfig.cropShapeType,
                                                        effectType: cropViewConfig.cropMaskVisualEffectType)
        
        dimmingView.overLayerFillColor = cropViewConfig.backgroundColor.cgColor
        visualEffectView.overLayerFillColor = cropViewConfig.backgroundColor.cgColor
        
        return CropMaskViewManager(dimmingView: dimmingView, visualEffectView: visualEffectView)
    }
    
    static func setupRotationControlViewIfNeeded(withConfig cropViewConfig: CropViewConfig,
                                                 cropView: CropView,
                                                 rotationControlView: RotationControlViewProtocol?) {
        if let rotationControlView = rotationControlView {
            if rotationControlView.isAttachedToCropView == false ||
                rotationControlView.isAttachedToCropView && cropViewConfig.showAttachedRotationControlView {
                cropView.rotationControlView = rotationControlView
            }
        } else {
            if cropViewConfig.showAttachedRotationControlView {
                switch cropViewConfig.builtInRotationControlViewType {
                case .rotationDial(let config):
                    let viewModel = RotationDialViewModel()
                    let dialPlate = RotationDialPlate(frame: .zero, config: config)
                    cropView.rotationControlView = RotationDial(frame: .zero,
                                                                config: config,
                                                                viewModel: viewModel,
                                                                dialPlate: dialPlate)
                case .slideDial(let config):
                    let viewModel = SlideDialViewModel()
                    let slideRuler = SlideRuler(frame: .zero, config: config)
                    cropView.rotationControlView = SlideDial(frame: .zero,
                                                             config: config,
                                                             viewModel: viewModel,
                                                             slideRuler: slideRuler)
                }
            }
        }
    }
}
