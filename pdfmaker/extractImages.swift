/*
    pdfmaker
    extractImages.swift

    Copyright © 2026 Tony Smith. All rights reserved.

    MIT License
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

import Foundation
import Quartz
import Clicore


extension Pdfmaker {

    /**
     Convert a PDF files to a set of images.

     - Parameters:
        - sourceIsDir  Does the global source file path lead to a directory?
        - destinationIsDir Does the global destination file path lead to a directory?

     - Returns: `true` on a successful completion, otherwise `false`.
     */
    internal static func pdfToImages(_ settings: Settings) -> Result<Bool, ProcessError> {

        // Make sure we're loading a PDF and outputting to a directory
        if !settings.destinationIsDir {
            return .failure(ProcessError(code: .destNotDir, text: "Chosen image destination \(settings.destination.path) is not a directory"))
        }

        if settings.sourceIsDir {
            return .failure(ProcessError(code: .sourceIsDir, text: "Source \(settings.source.path) is a directory"))
        }

        // Only proceed if the file is a PDF
        guard settings.source.pathExtension.lowercased() == "pdf" else {
            return .failure(ProcessError(code: .sourceNotPdf, text: "Source \(settings.source.path) is not a .pdf file"))
        }

        // Output info, if requested to do so
        if settings.doShowInfo {
            // We're in verbose mode, so show some info
            Stdio.report("Attempting to disassemble \(settings.source.path) to \(settings.destination.path)...")
            if settings.doCompress {
                reportCompressionLevel(settings.compressionLevel)
            }
        }

        // Initialise conversion values
        let scaleFactor = settings.outputResolution == BASE_DPI ? 1.0 : settings.outputResolution / BASE_DPI
        let imageProps: [NSBitmapImageRep.PropertyKey: Any] = [NSBitmapImageRep.PropertyKey.compressionFactor: settings.compressionLevel]
        var count = 0

        // Load and process the PDF
        do {
            // Get the PDF as data and convert it to a PDF Image Representation
            let fileData = try Data(contentsOf: URL(fileURLWithPath: settings.source.path))
            guard let pdfRep = NSPDFImageRep(data: fileData) else {
                return .failure(ProcessError(code: .badPdfExtract, text: "Could not extract the PDF data from \(settings.source.path)"))
            }

            // Process the PDF page by page
            for i in 0..<pdfRep.pageCount {
                // Run in an autorelease closure to avoid MAJOR memory gobbling. It all gets
                // freed by the garbage collector after the loop has completed, but while looping,
                // this code can allocate gigabytes of RAM (without autorelease)
                autoreleasepool {
                    // Draw the PDF page into an NSImage of the correct pixel dimensions
                    // (because the PDF size is in points)
                    pdfRep.currentPage = i

                    let newWidth = sizeAlign(pdfRep.size.width * scaleFactor)
                    let newHeight = sizeAlign(pdfRep.size.height * scaleFactor)
                    let newSize = CGSize(width: newWidth, height: newHeight)
                    let scaledImage = NSImage(size: newSize, flipped: false) { (drawRect) -> Bool in
                        pdfRep.draw(in: drawRect)
                        return true
                    }

                    // Convert the NSImage to a CGImage and then to a bitmap
                    // NOTE This code runs a lot more quickly than the above because it only calls
                    //      The NSImage drawing block once, not three times
                    if let ci = scaledImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        // Make the bitmap and set its DPI to 'outputResolution'
                        let bmp = NSBitmapImageRep(cgImage: ci)
                        if scaleFactor != 1.0 { setDPI(bmp, settings.outputResolution) }

                        // Convert the image to JPEG and save to disk
                        if let finalData = bmp.representation(using: .jpeg, properties: imageProps) {
                            let path = settings.destination.path + "/page " + String(format: "%03d", i + 1) + ".jpg"
                            do {
                                try finalData.write(to: URL(fileURLWithPath: path))
                                if settings.doShowInfo {
                                    reportInfo("Written image: \(path) of pixel size \(bmp.pixelsWide)x\(bmp.pixelsHigh)")
                                }
                                count += 1
                            } catch {
                                Stdio.reportError("Could not write file \(path)")
                            }
                        } else {
                            Stdio.reportError("Could not create an image for \(settings.source.path) page \(i)")
                        }
                    }
                }
            }

            if count > 0 { return .success(true) }
            return .failure(ProcessError(code: .noError))
        } catch {
            return .failure(ProcessError(code: .badFileLoad, text: "Could not load PDF file \(settings.source.path)"))
        }
    }

    
    /**
     Ensure an image dimension, whether width or height, is an integral multiple of 2.

     - Parameters:
        - dimension The chosen base (width or height)

     - Returns: The dimension's closest even value.
     */
    private static func sizeAlign(_ dimension: CGFloat) -> CGFloat {

        var returnValue = dimension.rounded(.down)

        if returnValue.truncatingRemainder(dividingBy: 2.0) != 0 {
            returnValue -= 1
        }

        return returnValue
    }


    /**
     Set the image DPI based on its pixel dimensions and the standard ('BASE') DPI.

     - Parameters:
        - imageRep The image for which the DPI will be set.
        - dpi      The required DPI.
     */
    private static func setDPI(_ imageRep: NSBitmapImageRep, _ dpi: CGFloat) {

        var size = imageRep.size
        size.width = CGFloat(imageRep.pixelsWide) * BASE_DPI / dpi
        size.height = CGFloat(imageRep.pixelsHigh) * BASE_DPI / dpi
        imageRep.size = size
    }

}
