////
////  PeopleSegmentationPickerViewController.swift
////
////
////  Created by Steven Nie on 12/25/23.
////
//
//import Foundation
//import UIKit
//import Vision
//import VisionKit
//
//class PeopleSegmentationPickerViewController: UIViewController {
//    let originalImage: UIImage
//    
//    lazy var originalImageView: UIImageView = {
//        let view = UIImageView()
//        view.contentMode = .scaleAspectFit
//        return view
//    }()
//    
//    lazy var spinnerView: UIActivityIndicatorView = {
//        let view = UIActivityIndicatorView(style: .medium)
//        view.startAnimating()
//        return view
//    }()
//        
//    init(originalImage: UIImage) {
//        self.originalImage = originalImage
//        super.init(nibName: nil, bundle: nil)
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        self.view.backgroundColor = .black
//        self.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel,
//                                                                primaryAction: UIAction { [weak self] _ in
//            self?.dismiss(animated: true)
//        })
//        
//        self.originalImageView.image = self.originalImage
//        self.view.addSubview(self.originalImageView)
//        self.view.addSubview(self.dimmingView)
//        self.dimmingView.addSubview(self.spinnerView)
//        
//        Task {
//            try? await self.startAnalysising()
//        }
//    }
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        
//        let boundingSize = self.view.bounds.size
//        var contentSize = boundingSize
//        contentSize.width -= (self.view.safeAreaInsets.left + self.view.safeAreaInsets.right)
//        contentSize.height -= (self.view.safeAreaInsets.top + self.view.safeAreaInsets.bottom)
//        self.originalImageView.frame = CGRect(x: (boundingSize.width - contentSize.width) / 2.0,
//                                              y: (boundingSize.height - contentSize.height) / 2.0,
//                                              width: contentSize.width,
//                                              height: contentSize.height)
//        self.dimmingView.frame = self.originalImageView.frame
//        self.spinnerView.sizeToFit()
//        self.spinnerView.frame = CGRect(x: (self.dimmingView.frame.width - self.spinnerView.frame.width) / 2.0,
//                                        y: (self.dimmingView.frame.height - self.spinnerView.frame.height) / 2.0,
//                                        width: self.spinnerView.frame.width,
//                                        height: self.spinnerView.frame.height)
//    }
//}
//
//private extension PeopleSegmentationPickerViewController {
//    enum PeopleSegmentationError: Error {
//        case failedToEncodeImage
//    }
//    
//    func startAnalysising() async throws {
//        guard let cgImage = self.originalImage.cgImage else {
//            throw PeopleSegmentationError.failedToEncodeImage
//        }
//        let request = VNGeneratePersonInstanceMaskRequest()
//        let requestHandler = VNImageRequestHandler(cgImage: cgImage,
//                                                   orientation: CGImagePropertyOrientation(self.originalImage.imageOrientation))
//
//        try requestHandler.perform([request])
//
//        for result in request.results ?? [] {
//            for index in result.allInstances {
//                let pixelBuffer = try result.generateScaledMaskForImage(forInstances: IndexSet(integer: index),
//                                                                        from: requestHandler)
//                var cgImage: CGImage?
//                VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
//                if let cgImage {
//                    let image = UIImage(cgImage: cgImage)
//                    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//                    if let filePath = paths.first?.appendingPathComponent("\(UUID().uuidString).png") {
//                        // Save image.
//                        do {
//                            print(filePath)
//                           try image.pngData()?.write(to: filePath, options: .atomic)
//                        } catch {
//                           // Handle the error
//                        }
//                    }
//
//                }
//            }
//        }
//    }
//}
