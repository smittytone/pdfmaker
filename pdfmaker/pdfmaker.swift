/*
    pdfmaker
    pdf.swift

    Copyright © 2025 Tony Smith. All rights reserved.

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


struct Pdf {

    /**
     Convert a set of images to a PDF. Images must be of supported types:
     currently PNG, JPG, TIF.

     - Parameters:
        - isSrcADir  Does the global source file path lead to a directory?
        - isDestADir Does the global destination file path lead to a directory?

     - Returns: `true` on a successful completion, otherwise `false`.
     */
    static func imagesToPdf(_ isSrcADir: Bool, _ isDestADir: Bool) -> Bool {

        // Determine the destination filename
        var filename: String
        if isDestADir {
            // Destination path indicates a directory, so prepare the filename
            filename = getFilename(destPath, (outputName == nil ? "PDF From Images via pdfmaker" : outputName!))
        } else {
            // Destination path indicates a file, so extract the filename
            // NOTE The file may not exist at this point -- we will make it later.
            filename = (destPath as NSString).lastPathComponent
            destPath = (destPath as NSString).deletingLastPathComponent

            // FROM 2.3.0 - Bug Fix
            // Ensure that the intermediate path is good (call will fail if it isn't)
            _ = checkDirectory(destPath, "Target")

            // Assemble the file name that will be used
            // NOTE Call adds a number to the end to avoid replacing an existing file
            //      of the same name
            filename = getFilename(destPath, filename)
        }

        // Set the destination path from the generated filename
        let savePath: String = destPath + "/" + filename

        if doShowInfo {
            // We're in verbose mode, so show some info
            Stdio.report("Attempting to assemble \(savePath) from \(sourcePath)...")
            if doCompress {
                showCompression()
            }
        }

        var files: [String]

        if isSrcADir {
            // We have a directory of files, so load a list of items into 'files'
            do {
                // Get a list of files in the source directory and sort them so that they get added
                // to the output PDF in the correct order
                files = try FileManager.default.contentsOfDirectory(atPath: sourcePath)
                files.sort()
            } catch {
                // NOTE This should not be triggered due to earlier checks
                Stdio.reportError("Unable to get contents of directory \(sourcePath)")
                return false
            }
        } else {
            // 'srcDir' points to a file, so add it to files array manually
            files = [sourcePath]
        }

        // Initialise counters and flags
        var pageCount: Int = 0
        var pdfKitErr: Bool = false

        // Prepare a PDF Document
        var pdf: PDFDocument? = nil

        // Iterate through the list of files
        for i in 0..<files.count {
            // Get a file, making sure it's not a . file
            var file: String
            if isSrcADir {
                // FROM 1.1.0
                // Ignore . files
                if files[i].hasPrefix(".") { continue }
                file = sourcePath + "/" + files[i]
            } else {
                file = files[i]
            }

            // Get the file extension
            let ext: String = (file as NSString).pathExtension.lowercased()

            reportInfo("Found file: \(file), \(ext.count == 0 ? "ignoring" : "processing")")

            // FROM 2.1.1
            // Support loading of PNG, JPG, HEIC, TIF, WEBP
            let supportedImageTypes: [String] = ["jpg", "jpeg", "png", "tiff", "tif", "heic", "webp", "bmp"]
            if supportedImageTypes.contains(ext) {
                // Load the image
                var image: NSImage? = NSImage.init(contentsOfFile: file)
                if image != nil {
                    if doCompress && (ext == "jpg" || ext == "jpeg") {
                        // Re-compress the image
                        // NOTE Since we're loading from JPEG, the image may already by compressed
                        image = compressImage(image!)

                        // Break on error
                        if image == nil {
                            Stdio.reportWarning("Could not compress image \(file), ignoring")
                            continue
                        }
                    }

                    // Create a PDF page based on the image
                    // Error 'CoreGraphics PDF has logged an error... Invalid image orientation, assuming 1'
                    // generated by the next call
                    grabber.openConsolePipe()
                    if let page: PDFPage = PDFPage.init(image: image!) {
                        pdfKitErr = grabber.closeConsolePipe()

                        // FROM 1.1.2
                        // Set the mediaBox size
                        page.setBounds(CGRect.init(x: 0,
                                                   y: 0,
                                                   width: image!.size.width,
                                                   height: image!.size.height),
                                       for: .mediaBox)

                        if pageCount == 0 {
                            // This will be the first page in the PDF, so initialize
                            // the PDF with the page data
                            if let pageData: Data = page.dataRepresentation {
                                pdf = PDFDocument.init(data: pageData)
                                pageCount += 1
                            } else {
                                Stdio.reportError("Could not add page \(pageCount) for image \(file)")
                            }
                        } else {
                            if let newpdf: PDFDocument = pdf {
                                // We're adding a page to the already created PDF,
                                // so just insert the page
                                newpdf.insert(page, at: pageCount)
                                pageCount += 1
                            } else {
                                Stdio.reportError("Could not add page \(pageCount) for image \(file)")
                            }
                        }
                    } else {
                        Stdio.reportError("Could not create page for image \(file)")
                    }
                } else {
                    Stdio.reportError("Could not load image \(file)")
                }
            } else {
                Stdio.reportWarning("File \(file) is not a supported image type, ignoring")
            }
        }

        // Did we add any images to the PDF?
        if pageCount > 0 {
            // Yes we did, so save the PDF to disk
            if let newpdf: PDFDocument = pdf {
                reportInfo("Writing PDF file \(savePath)")

                // Did PDFKit complain?
                if pdfKitErr {
                    processPdfKitErrors()
                }

                // Write the file to disk
                newpdf.write(toFile: savePath)
                return true
            }
        } else {
            Stdio.reportWarning("No suitable image files found in the source directory")
        }

        return false
    }


    /**
     Display errors generated directly by PDFKit.

     PDFKit issues file errors directly to `STDERR`, so we trap these elsewhere
     (see `output-grabber.swift` and here de-dupe the errors from PDFKit and
     output the remaining errors.

     FROM 2.3.7
     */
    static func processPdfKitErrors() {

        if doShowInfo || grabber.verboseErrSet {
            // List all the errors if we're in pdfmaker verbose mode,
            // or the `CG_PDF_VERBOSE` env var has been set
            var errString: String = ""
            for (index, error) in grabber.errors.enumerated() {
                errString += "“" + error + "” (Count: \(grabber.errorCounts[index])), "
            }

            if !errString.isEmpty {
                Stdio.reportWarning("PDFKit issued these messages: \(errString[errString.startIndex...errString.index(errString.endIndex, offsetBy: -2)])")
            }
        } else {
            // Issue a base warning
            Stdio.reportWarning("PDFKit grumbled about one or more images. For more information, set the environment variable CG_PDF_VERBOSE before running pdfmaker next time")
        }
    }


    /**
     Convert a PDF files to a set of images.

     - Parameters:
        - isSrcADir  Does the global source file path lead to a directory?
        - isDestADir Does the global destination file path lead to a directory?

     - Returns: `true` on a successful completion, otherwise `false`.
     */
    static func pdfToImages(_ isSrcADir: Bool, _ isDestADir: Bool) -> Bool {

        // Make sure we're loading a PDF and outputting to a directory
        if !isDestADir {
            Stdio.reportError("Chosen image destination \(destPath) is not a directory")
            return false
        }

        if isSrcADir {
            Stdio.reportError("Source \(sourcePath) is a directory")
            return false
        }

        // Get the file extension
        let ext: String = (sourcePath as NSString).pathExtension.lowercased()

        // Only proceed if the file is a PDF
        if ext == "pdf" {
            // Output info, if requested to do so
            if doShowInfo {
                // We're in verbose mode, so show some info
                Stdio.report("Attempting to disassemble \(sourcePath) to \(destPath)...")
                if doCompress {
                    showCompression()
                }
            }

            // Initialise conversion values
            let scaleFactor: CGFloat = outputResolution == BASE_DPI ? 1.0 : outputResolution / BASE_DPI
            let imageProps: [NSBitmapImageRep.PropertyKey: Any] = [NSBitmapImageRep.PropertyKey.compressionFactor: compressionLevel]
            var count: Int = 0

            // Load and process the PDF
            do {
                // Get the PDF as data and convert it to a PDF Image Representation
                let fileData: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: sourcePath))
                if let pdfRep: NSPDFImageRep = NSPDFImageRep.init(data: fileData) {
                    // Process the PDF page by page
                    for i in 0..<pdfRep.pageCount {
                        // Run in an autorelease closure to avoid MAJOR memory gobbling. It all gets
                        // freed by the garbage collector after the loop has completed, but while looping,
                        // this code can allocate gigabytes of RAM (without autorelease)
                        autoreleasepool {
                            // Draw the PDF page into an NSImage of the correct pixel dimensions
                            // (because the PDF size is in points)
                            pdfRep.currentPage = i

                            let newWidth: CGFloat = sizeAlign(pdfRep.size.width * scaleFactor)
                            let newHeight: CGFloat = sizeAlign(pdfRep.size.height * scaleFactor)
                            let newSize: CGSize = CGSize.init(width: newWidth, height: newHeight)
                            let scaledImage: NSImage = NSImage.init(size: newSize, flipped: false) { (drawRect) -> Bool in
                                pdfRep.draw(in: drawRect)
                                return true
                            }

                            // Convert the NSImage to a CGImage and then to a bitmap
                            // NOTE This code runs a lot more quickly than the above because it only calls
                            //      The NSImage drawing block once, not three times
                            if let ci: CGImage = scaledImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                // Make the bitmap and set its DPI to 'outputResolution'
                                let bmp: NSBitmapImageRep = NSBitmapImageRep.init(cgImage: ci)
                                if scaleFactor != 1.0 { setDPI(bmp, outputResolution) }

                                // Convert the image to JPEG and save to disk
                                if let finalData: Data = bmp.representation(using: .jpeg, properties: imageProps) {
                                    let path: String = destPath + "/page " + String(format: "%03d", i + 1) + ".jpg"
                                    do {
                                        try finalData.write(to: URL.init(fileURLWithPath: path))
                                        reportInfo("Written image: \(path) of pixel size \(bmp.pixelsWide)x\(bmp.pixelsHigh)")
                                        count += 1
                                    } catch {
                                        Stdio.reportError("Could not write file \(path)")
                                    }
                                } else {
                                    Stdio.reportError("Could not create an image for \(sourcePath) page \(i)")
                                }
                            }
                        }
                    }

                    if count > 0 { return true }
                } else {
                    Stdio.reportError("Could not extract the PDF data from \(sourcePath)")
                }
            } catch {
                Stdio.reportError("Could not load file \(sourcePath)")
            }
        } else {
            Stdio.reportError("Source \(sourcePath) is not a .pdf file")
        }

        return false
    }


    /**
     Extract the text from the PDF file, if possible, and save it.

     FROM 2.4.0

     - Parameters:
        - isSrcADir  Does the global source file path lead to a directory?
        - isDestADir Does the global destination file path lead to a directory?

     - Returns: `true` on a successful completion, otherwise `false`.
     */
    static func pdfToText(_ isSrcADir: Bool, _ isDestADir: Bool) -> Bool {

        // Make sure we're loading a PDF and outputting to a directory
        if isSrcADir {
            Stdio.reportError("Source \(sourcePath) is a directory")
            return false
        }

        // Hold data is an attributed string, in case we want to make something
        // with it in a future release, eg. RTF file
        let documentContent = NSMutableAttributedString()
        let ext: String = (sourcePath as NSString).pathExtension.lowercased()

        // Only proceed if the file is a PDF
        if ext == "pdf" {
            do {
                // Get data from the file...
                let fileData: Data = try Data(contentsOf: URL(fileURLWithPath: sourcePath))

                // ...and see if it's a PDF
                if let pdf = PDFDocument(data: fileData) {
                    // Extract the text from each page as an NSAttributedString
                    for i in 0 ..< pdf.pageCount {
                        guard let page = pdf.page(at: i) else { continue }
                        guard let pageContent = page.attributedString else { continue }
                        documentContent.append(pageContent)
                    }

                    // If we have gathered some text, output it to a file
                    if !documentContent.string.isEmpty {
                        if let finalData: Data = documentContent.string.data(using: .utf8) {
                            var path: String
                            if isDestADir {
                                // User has passed a directory as the destination so assemble
                                // a filename based on the source
                                let fileName = (sourcePath as NSString).lastPathComponent
                                let parts = fileName.components(separatedBy: ".")
                                path = destPath + "/" + parts[0] + ".txt"
                            } else {
                                path = destPath
                            }

                            do {
                                try finalData.write(to: URL(fileURLWithPath: path))
                                reportInfo("Written text: \(path)")
                                return true
                            } catch {
                                Stdio.reportError("Could not write file \(path)")
                            }
                        } else {
                            Stdio.reportError("Could not create a file for \(sourcePath)’s text content")
                        }
                    } else {
                        Stdio.reportError("Could not create a text file for \(sourcePath)")
                    }
                } else {
                    Stdio.reportError("\(sourcePath) does not appear to be a PDF file")
                }
            } catch {
                Stdio.reportError("Could not load file \(sourcePath)")
            }
        }

        return false
    }


    /**
     Run through the files in the specified directory and set the output
     file's name so that it doesn't clash with existing files. For example,
     if `Untitled.pdf` exists, this will generate `Untitled 01.pdf`

     - Parameters:
        - filepath The directory's path.
        - basename The base output filename to which integers will be appended.

     - Returns: The new file name, or the existing one if it's OK.
     */
    static func getFilename(_ filepath: String, _ basename: String) -> String {

        // If the passed filename has a '.pdf' extension, remove it
        var newBasename: String = basename

        let pathExt: String = (newBasename as NSString).pathExtension.lowercased()
        if pathExt == "pdf" {
            newBasename = (newBasename as NSString).deletingPathExtension
        } else if pathExt != "" {
            // NOT a PDF file, so bail
            Stdio.reportErrorAndExit("\(newBasename) does not reference a PDF file")
        }

        // Assemble the target filename
        var newFilename: String = newBasename + ".pdf"
        var i: Int = 0

        // Does a file with the target filename exist?
        while FileManager.default.fileExists(atPath: (filepath + "/" + newFilename)) {
            // The named file exists, so add a numeric suffix to the filename and re-check
            i += 1
            newFilename = newBasename + String(format: " %02d", i) + ".pdf"
        }

        // FROM 2.0.1
        // Bail if the filename exceeds 255 UTF-8 characters
        // TODO Make this more intelligent: truncate the file name?
        if newFilename.count > 255 {
            Stdio.reportErrorAndExit("Generated filename \(newFilename) is too long -- please provide a filename")
        }

        // Send back the derived name
        return newFilename
    }


    /**
     Check whether the item at the provided path is a directory or a regular file.

     - Parameters:
        - path    A path to a file or directory, existent or non-existent.
        - dirType Whether the path leads to a source or target entity.

     - Returns: `true` if the file is an existing directory, `false` if it's a file,
                a non-existent file, or a non-existent directory that can't be created/
     */
    static func checkDirectory(_ path: String, _ dirType: String) -> Bool {

        var isDir: ObjCBool = true
        let success: Bool = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

        if success {
            // The path points to an existing item, so return its type
            return isDir.boolValue
        }

        // Is the non-existent item a file, ie. does it have an extension?
        let ext: String = (path as NSString).pathExtension

        if ext.count > 0 {
            // There is an extension, so assume it points to a file,
            // which we will create later
            return false
        }

        // FROM 2.3.0
        // Try and make intermediate directories if we can and are asked to
        if doMakeSubDirectories {
            do {
                try FileManager.default.createDirectory(at: URL.init(fileURLWithPath: path),
                                                              withIntermediateDirectories: true,
                                                              attributes: nil)
            } catch {
                Stdio.reportErrorAndExit("\(dirType) directory \(path) does not exist and cannot be created")
            }
        } else {
            Stdio.reportErrorAndExit("\(dirType) directory \(path) does not exist. Use the --createdirs switch")
        }

        return true
    }


    /**
     Compress an image.

     - Parameters:
        - image The chosen image.

     - Returns: The compressed image, or `nil` on error.
     */
    static func compressImage(_ image: NSImage) -> NSImage? {

        if let tiff = image.tiffRepresentation {
            if let imageRep: NSBitmapImageRep = NSBitmapImageRep.init(data: tiff) {
                if let compressedData: Data = imageRep.representation(using: NSBitmapImageRep.FileType.jpeg,
                                                                      properties: [NSBitmapImageRep.PropertyKey.compressionFactor : compressionLevel]) {

                    // FROM 2.3.5 -- ignore image orientation
                    return NSImage.init(dataIgnoringOrientation: compressedData)
                }
            }
        }

        // Something went wrong, so just return nil
        return nil
    }


    /**
     Display the chosen image compression level.
     */
    static func showCompression() {

        let percent: Int = Int(compressionLevel * 100)
        var amount = "\(percent)%"
        if percent == 0 { amount = "Least (" + amount + ")" }
        if percent == 100 { amount = "Maxiumum (" + amount + ")" }
        Stdio.report("     Quality: " + amount)
    }


    /**
     Ensure an image dimension, whether width or height, is an integral multiple of 2.

     - Parameters:
        - dimension The chosen base (width or height)

     - Returns: The dimension's closest even value.
     */
    static func sizeAlign(_ dimension: CGFloat) -> CGFloat {

        var returnValue: CGFloat = dimension.rounded(.down)

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
    static func setDPI(_ imageRep: NSBitmapImageRep, _ dpi: CGFloat) {

        var size: CGSize = imageRep.size
        size.width = CGFloat(imageRep.pixelsWide) * BASE_DPI / dpi
        size.height = CGFloat(imageRep.pixelsHigh) * BASE_DPI / dpi
        imageRep.size = size
    }


    /**
     Report information, if requested by the user.
     */
    static func reportInfo(_ message: String) {

        if doShowInfo {
            Stdio.report(message)
        }
    }
}
