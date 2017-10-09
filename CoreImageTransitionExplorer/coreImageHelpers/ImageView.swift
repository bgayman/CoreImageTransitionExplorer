//
//  ImageView.swift
//  CoreImageHelpers
//
//  Created by Simon Gladman on 09/01/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import GLKit
import UIKit

/// `ImageView` wraps up a `GLKView` and its delegate into a single class to simplify the
/// display of `CIImage`.
///
/// `ImageView` is hardcoded to simulate ScaleAspectFit: images are sized to retain their
/// aspect ratio and fit within the available bounds.
///
/// `ImageView` also respects `backgroundColor` for opaque colors

class ImageView: GLKView
{
    let eaglContext = EAGLContext(api: .openGLES2)
    
    lazy var ciContext: CIContext =
    {
        [unowned self] in
        
        return CIContext(eaglContext: self.eaglContext!,
            options: [kCIContextWorkingColorSpace: NSNull()])
        }()
    
    override init(frame: CGRect)
    {
        super.init(frame: frame, context: eaglContext!)
        
        context = self.eaglContext!
        delegate = self
    }
    
    override init(frame: CGRect, context: EAGLContext)
    {
        fatalError("init(frame:, context:) has not been implemented")
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// The image to display
    var image: CIImage?
        {
        didSet
        {
            setNeedsDisplay()
        }
    }
}

extension ImageView: GLKViewDelegate
{
    func glkView(_ view: GLKView, drawIn rect: CGRect)
    {
        guard let image = image else
        {
            return
        }
        
        let sourceAspect = image.extent.width / image.extent.height
        
        let targetWidth: Int
        let targetHeight: Int
        let targetX: Int
        let targetY: Int
        
        if image.extent.width > image.extent.height
        {
            // rescale and position for landscape source
            
            targetWidth = drawableWidth
            targetHeight = Int(CGFloat(drawableWidth) / sourceAspect)
            
            targetX = 0
            targetY = (drawableHeight / 2) - (targetHeight / 2)
        }
        else if image.extent.width < image.extent.height
        {
            // rescale and position for portrait source
            
            targetHeight = drawableHeight
            targetWidth = Int(CGFloat(drawableHeight) * sourceAspect)
            
            targetX = (drawableWidth / 2) - (targetWidth / 2)
            targetY = 0
        }
        else if drawableWidth > drawableHeight
        {
            // rescale and position for square source and landscape target
            
            targetWidth = drawableHeight
            targetHeight = drawableHeight
            
            targetX = (drawableWidth / 2) - (targetWidth / 2)
            targetY = 0
        }
        else if drawableWidth < drawableHeight
        {
            // rescale and position for square source and portrait target
            
            targetWidth = drawableWidth
            targetHeight = drawableWidth
            
            targetX = 0
            targetY = (drawableHeight / 2) - (targetHeight / 2)
        }
        else
        {
            targetWidth = drawableWidth
            targetHeight = drawableHeight
            
            targetX = 0
            targetY = 0
        }
        
        let ciBackgroundColor = CIColor(color: backgroundColor ?? UIColor.white)
        
        ciContext.draw(CIImage(color: ciBackgroundColor),
            in: CGRect(x: 0,
                y: 0,
                width: drawableWidth,
                height: drawableHeight),
            from: CGRect(x: 0,
                y: 0,
                width: drawableWidth,
                height: drawableHeight))
        
        ciContext.draw(image,
            in: CGRect(x: targetX,
                y: targetY,
                width: targetWidth,
                height: targetHeight),
            from: image.extent)
    }
}
