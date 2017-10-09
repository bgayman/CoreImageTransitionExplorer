//
//  ViewController.swift
//  CoreImageTransitionExplorer
//
//  Created by Simon Gladman on 10/01/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController
{
    let manager = PHImageManager.default()
    lazy var requestOptions: PHImageRequestOptions =
    {
        [unowned self] in
        
        let requestOptions = PHImageRequestOptions()
        
        requestOptions.deliveryMode = PHImageRequestOptionsDeliveryMode.opportunistic
        requestOptions.resizeMode = PHImageRequestOptionsResizeMode.exact
        requestOptions.isNetworkAccessAllowed = true
        
        requestOptions.progressHandler = {
            (value: Double, _: NSError?, _ : UnsafeMutablePointer<ObjCBool>, _ : [AnyHashable: Any]?) in
            DispatchQueue.main.async
            {
                self.progressBar.setProgress(Float(value), animated: true)
            }
        } as? PHAssetImageProgressHandler

        return requestOptions
    }()
  
    let imageView = ImageView()
    
    let progressBar = UIProgressView(progressViewStyle: .bar)
    
    let transitionSegmentedControl = UISegmentedControl(items: ["CIDissolveTransition", "CIBarsSwipeTransition",
        "CIModTransition", "CISwipeTransition",
        "CICopyMachineTransition", "CIFlashTransition", "CIRippleTransition",
        "BlurTransition", "CircleTransition", "StarTransition"].sorted())
    
    var transitionTime = 0.0
    let transitionStep = 0.005
    
    lazy var assets = ViewController.getAllAssets()
    
    var imageOne: CIImage?
    var imageTwo: CIImage?
    var imageOneIsTransitionTarget: Bool = false
    
    let returnImageSize = CGSize(width: 1024, height: 1024)
    static let rect1024x1024 = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    
    var randomAssetIndex: Int
    {
        return Int(arc4random_uniform(UInt32(assets.count - 1)))
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        BlurTransition.register()
        CircleTransition.register()
        StarTransition.register()
        
        view.backgroundColor = UIColor.black
        imageView.backgroundColor = UIColor.black
        
        view.addSubview(imageView)
        
        // ---
        
        view.addSubview(progressBar)
        
        // ---
        
        transitionSegmentedControl.selectedSegmentIndex = 0
        view.addSubview(transitionSegmentedControl)
        
        // ---

        PHPhotoLibrary.requestAuthorization { (status) -> Void in
            if status == .authorized {
                self.requestAssets()
            }
        }
    }

    func requestAssets()
    {
        manager.requestImage(for: assets[randomAssetIndex],
            targetSize: returnImageSize,
            contentMode: PHImageContentMode.aspectFit,
            options: requestOptions,
            resultHandler: imageRequestResultHandler)

        manager.requestImage(for: assets[randomAssetIndex],
            targetSize: returnImageSize,
            contentMode: PHImageContentMode.aspectFit,
            options: requestOptions,
            resultHandler: imageRequestResultHandler)

        let displayLink = CADisplayLink(target: self, selector: #selector(ViewController.step))
        displayLink.add(to: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
    }

    @objc func step()
    {
        guard let imageOne = imageOne, let imageTwo = imageTwo else
        {
            return
        }
  
        let transformFilterOne = CIFilter(name: "CIAffineTransform",
            withInputParameters: [kCIInputImageKey: imageOne,
                kCIInputTransformKey: ViewController.centerImageTransform(imageOne)])!
        
  
        let transformFilterTwo = CIFilter(name: "CIAffineTransform",
            withInputParameters: [kCIInputImageKey: imageTwo,
                kCIInputTransformKey: ViewController.centerImageTransform(imageTwo)])!
        
        // ---

        let source = CompositeOverBlackFilter()
        source.inputImage = imageOneIsTransitionTarget ? transformFilterOne.outputImage! : transformFilterTwo.outputImage!
        
        let target = CompositeOverBlackFilter()
        target.inputImage = imageOneIsTransitionTarget ? transformFilterTwo.outputImage! : transformFilterOne.outputImage!
   
        let transitionName = transitionSegmentedControl.titleForSegment(at: transitionSegmentedControl.selectedSegmentIndex)!
        
        let transition = CIFilter(name: transitionName,
            withInputParameters: [kCIInputImageKey: source.outputImage,
                kCIInputTargetImageKey: target.outputImage,
                kCIInputTimeKey: transitionTime])!

        if transition.inputKeys.contains(kCIInputExtentKey)
        {
            transition.setValue(CIVector(cgRect: ViewController.rect1024x1024),
                forKey: kCIInputExtentKey)
        }
        
        if transition.inputKeys.contains(kCIInputCenterKey)
        {
            transition.setValue(CIVector(x: returnImageSize.width / 2, y: returnImageSize.height / 2),
                forKey: kCIInputCenterKey)
        }
        
        if transition.inputKeys.contains(kCIInputShadingImageKey)
        {
            transition.setValue(CIImage(),
                forKey: kCIInputShadingImageKey)
        }

        imageView.image = transition.outputImage!
        
        transitionTime += transitionStep
        
        if transitionTime > 1
        {
            transitionTime = 0
                    
            if imageOneIsTransitionTarget
            {
                self.imageOne = nil
            }
            else
            {
                self.imageTwo = nil
            }
            
            manager.requestImage(for: assets[randomAssetIndex],
                targetSize: returnImageSize,
                contentMode: PHImageContentMode.aspectFit,
                options: requestOptions,
                resultHandler: imageRequestResultHandler)
                    
        }
    }
    
    /// Returns an NSValue containing an affine transform to center an CIImage within
    /// a square bounding box
    static func centerImageTransform(_ image: CIImage) -> NSValue
    {
        let transform: NSValue
            
        if image.extent.width > image.extent.height
        {
            let dy = image.extent.width / 2 - image.extent.height / 2
            transform = NSValue(cgAffineTransform: CGAffineTransform(translationX: 0, y: dy))
        }
            else
        {
            let dx = image.extent.height / 2 - image.extent.width / 2
            transform = NSValue(cgAffineTransform: CGAffineTransform(translationX: dx, y: 0))
        }

        return transform
    }
    
    /// Returns an array of all Image assets for collection type Moment
    static func getAllAssets() -> [PHAsset]
    {
        var assets = [PHAsset]()
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %i", PHAssetMediaType.image.rawValue)
        
        
        let assetCollections = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.moment,
            subtype: PHAssetCollectionSubtype.albumRegular,
            options: nil)
        
        for index in 0 ..< assetCollections.count
        {
            let assetCollection = assetCollections[index] as PHAssetCollection
            
            let assetsInCollection = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
            
            let range = IndexSet(integersIn: 0 ..< assetsInCollection.count)
            
            let assetsArray = assetsInCollection.objects(at: range) as [PHAsset]
            assets.append(contentsOf: assetsArray)
        }
        
        return assets
    }
    
    func imageRequestResultHandler(_ image: UIImage?, properties: [AnyHashable: Any]?)
    {
        guard let image = image else
        {
            return;
        }
     
        let imageResult = CIImage(image: image)?.oriented(forExifOrientation: imageOrientationToTiffOrientation(image.imageOrientation))
        
        if imageOneIsTransitionTarget
        {
            imageOne = imageResult
        }
        else
        {
            imageTwo = imageResult
        }
        DispatchQueue.main.async
        {
            self.progressBar.progress = 0
        }
        
        
        imageOneIsTransitionTarget = !imageOneIsTransitionTarget
    }


    override func viewDidLayoutSubviews()
    {
        imageView.frame = view.bounds.insetBy(dx: 50, dy: 50)
        
        transitionSegmentedControl.frame = CGRect(x: 0,
            y: view.frame.height - transitionSegmentedControl.intrinsicContentSize.height,
            width: view.frame.width,
            height: transitionSegmentedControl.intrinsicContentSize.height)
        
        progressBar.frame = CGRect(x: 0,
            y: topLayoutGuide.length,
            width: view.frame.width,
            height: progressBar.intrinsicContentSize.height).insetBy(dx: 10, dy: 0)
    }

    override var preferredStatusBarStyle : UIStatusBarStyle
    {
        return UIStatusBarStyle.lightContent
    }

}


func imageOrientationToTiffOrientation(_ value: UIImageOrientation) -> Int32
{
    switch (value)
    {
    case UIImageOrientation.up:
        return 1
    case UIImageOrientation.down:
        return 3
    case UIImageOrientation.left:
        return 8
    case UIImageOrientation.right:
        return 6
    case UIImageOrientation.upMirrored:
        return 2
    case UIImageOrientation.downMirrored:
        return 4
    case UIImageOrientation.leftMirrored:
        return 5
    case UIImageOrientation.rightMirrored:
        return 7
    }
}
