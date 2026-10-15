/*
    pdfmaker
    combineImages.swift

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
     Convert a set of images to a PDF. Images must be of supported types:
     currently PNG, JPG, TIF.

     - Parameters:
        - sourceIsDir  Does the global source file path lead to a directory?
        - destIsDir Does the global destination file path lead to a directory?

     - Returns: `true` on a successful completion, otherwise `false`.
     */
    internal static func imagesToPdf(_ settings: Settings) -> Result<Bool, ProcessError> {

        // Determine the destination filename
        var targetFilename = ""
        var targetDirectory = settings.destination
        if settings.destIsDir {
            // Destination is a directory, so prepare the filename
            targetFilename = getFilename(settings.destination, (settings.outputName == nil ? "PDF From Images via pdfmaker" : settings.outputName!))
        } else {
            // Destination path indicates a file, so extract the filename
            // NOTE The file may not exist at this point -- we will make it later.
            targetFilename = settings.destination.lastPathComponent
            targetDirectory = settings.destination.deletingLastPathComponent()

            // FROM 2.3.0 - Bug Fix
            // Ensure that the intermediate path is good (`imagesToPdf()` will fail if it isn't)
            // We call this to make the internediates
            _ = check(directory: targetDirectory, .target, settings.doMakeSubDirectories)

            // Assemble the file name that will be used
            // NOTE Call adds a number to the end to avoid replacing an existing file
            //      of the same name
            targetFilename = getFilename(targetDirectory, targetFilename)
        }

        // Set the destination path from the generated filename
        let targetFile = targetDirectory.appendingPathComponent(targetFilename)

        if settings.doShowInfo {
            // We're in verbose mode, so show some info
            Stdio.report("Attempting to assemble \(targetFile.path) from \(settings.source.path)...")
            if settings.doCompress {
                reportCompressionLevel(settings.compressionLevel)
            }
        }

        var sourceFiles: [String]

        if settings.sourceIsDir {
            // We have a directory of files, so load a list of items into 'files'
            do {
                // Get a list of files in the source directory and sort them so that they get added
                // to the output PDF in the correct order
                sourceFiles = try FileManager.default.contentsOfDirectory(atPath: settings.source.path)
                sourceFiles.sort()
            } catch {
                // NOTE This should not be triggered due to earlier checks
                return .failure(ProcessError(code: .badDirLoad, text: "Unable to get contents of directory \(settings.source.path)"))
            }
        } else {
            // `settings.source` points to a file, so add it to files array manually
            sourceFiles = [settings.source.path]
        }

        // Initialise counters and flags
        var pageCount = 0
        var pdfKitErr = false

        // Prepare a PDF Document
        let pdf: PDFDocument? = PDFDocument()

        // Iterate through the list of files
        for i in 0..<sourceFiles.count {
            // Get a file, making sure it's not a . file
            var file: String
            if settings.sourceIsDir {
                // FROM 1.1.0
                // Ignore . files
                if sourceFiles[i].hasPrefix(".") { continue }
                file = settings.source.path + "/" + sourceFiles[i]
            } else {
                file = sourceFiles[i]
            }

            // Get the file extension
            let ext = (file as NSString).pathExtension.lowercased()

            if settings.doShowInfo {
                reportInfo("Found file: \(file), \(ext.count == 0 ? "ignoring" : "processing")")
            }

            // FROM 2.1.1
            // Support loading of PNG, JPG, HEIC, TIF, WEBP
            guard SUPPORTED_IMAGE_TYPES.contains(ext) else {
                Stdio.reportWarning("File \(file) is not a supported image type, ignoring")
                continue
            }

            // Load the image
            var image = NSImage(contentsOfFile: file)
            guard image != nil else {
                Stdio.reportError("Could not load image \(file)")
                continue
            }

            if settings.doCompress && (ext == "jpg" || ext == "jpeg") {
                // Re-compress the image
                // NOTE Since we're loading from JPEG, the image may already by compressed
                image = compressImage(image!, settings.compressionLevel)

                // Break on error
                if image == nil {
                    Stdio.reportWarning("Could not compress image \(file), ignoring")
                    continue
                }
            }

            // Create a PDF page based on the image
            // Error 'CoreGraphics PDF has logged an error... Invalid image orientation, assuming 1'
            // generated by the next call
            settings.grabber.openConsolePipe()
            guard let page = PDFPage(image: image!) else {
                Stdio.reportError("Could not create page for image \(file)")
                continue
            }

            // FROM 2.5.0
            // Don't clear `pdfKitErr` if `closeConsolePipe()` returns `false` on subsequent run
            if settings.grabber.closeConsolePipe(), !pdfKitErr {
                pdfKitErr = true
            }

            // FROM 1.1.2
            // Set the mediaBox size
            page.setBounds(CGRect(x: 0,
                                  y: 0,
                                  width: image!.size.width,
                                  height: image!.size.height),
                           for: .mediaBox)

            // FROM 2.5.0
            // Simplify PDF document creation and addition
            // NOTE This avoids the Tahoe-introduced `can't draw page when it has no document` issue
            if let newpdf = pdf {
                // Insert the page
                newpdf.insert(page, at: pageCount)
                pageCount += 1
            } else {
                Stdio.reportError("Could not add page \(pageCount) for image \(file)")
            }
        }

        // Did we add any images to the PDF?
        if pageCount > 0 {
            // Yes we did, so save the PDF to disk
            if let newpdf = pdf {
                if settings.doShowInfo {
                    reportInfo("Writing PDF file \(targetFile.path)")
                }

                // Did PDFKit complain?
                if pdfKitErr {
                    processPdfKitErrors(settings.grabber, settings.doShowInfo)
                }

                // FROM 2.5.0
                // If metadata has been set, apply it to the PDFDocument
                if newpdf.documentAttributes != nil {
                    if !settings.metadata.title.isEmpty {
                        newpdf.documentAttributes![PDFDocumentAttribute.titleAttribute] = settings.metadata.title
                    }

                    if !settings.metadata.subject.isEmpty {
                        newpdf.documentAttributes![PDFDocumentAttribute.subjectAttribute] = settings.metadata.subject
                    }

                    if !settings.metadata.author.isEmpty {
                        newpdf.documentAttributes![PDFDocumentAttribute.authorAttribute] = settings.metadata.author
                    }

                    // Set the standard creator
                    newpdf.documentAttributes![PDFDocumentAttribute.creatorAttribute] = "pdfmaker " + getVersion(withBuild: false)
                }

                // Write the file to disk
                var success = false
                if !settings.metadata.password.isEmpty {
                    // FROM 2.5.0
                    // If a password has been set, apply it as the admin password to the PDFDocument
                    // NOTE Only apply access permissions for encrypted docs
                    success = newpdf.write(toFile: targetFile.path, withOptions: [
                                .ownerPasswordOption: settings.metadata.password,
                                .accessPermissionsOption: setPermissions()
                    ])
                } else {
                    // Or, as before, just write an unencrypted PDF
                    success = newpdf.write(toFile: targetFile.path)
                }

                return success ? .success(true) : .failure(ProcessError(code: .badPdfWrite, text: targetFile.path))
            }
        }

        Stdio.reportWarning("No suitable image files found in the source directory")
        return .failure(ProcessError(code: .noError))
    }


    /**
     Display errors generated directly by PDFKit.

     PDFKit issues file errors directly to `STDERR`, so we trap these elsewhere
     (see `output-grabber.swift` and here de-dupe the errors from PDFKit and
     output the remaining errors.

     FROM 2.3.7
     */
    private static func processPdfKitErrors(_ grabber: OutputGrabber, _ report: Bool) {

        if report || grabber.verboseErrSet {
            // List all the errors if we're in pdfmaker verbose mode,
            // or the `CG_PDF_VERBOSE` env var has been set
            var errString = ""
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
     Compress an image.

     - Parameters:
        - image The chosen image.

     - Returns: The compressed image, or `nil` on error.
     */
    private static func compressImage(_ image: NSImage, _ compressionLevel: CGFloat) -> NSImage? {

        if let tiff = image.tiffRepresentation {
            if let imageRep = NSBitmapImageRep(data: tiff) {
                if let compressedData = imageRep.representation(using: NSBitmapImageRep.FileType.jpeg,
                                                                properties: [NSBitmapImageRep.PropertyKey.compressionFactor : compressionLevel]) {

                    // FROM 2.3.5 -- ignore image orientation
                    return NSImage(dataIgnoringOrientation: compressedData)
                }
            }
        }

        // Something went wrong, so just return nil
        return nil
    }


    private static func setPermissions() -> UInt {

        /*
         PDFKit defines the following enum:

        public enum PDFAccessPermissions : UInt, @unchecked Sendable {
            case allowsLowQualityPrinting = 1
            case allowsHighQualityPrinting = 2
            case allowsDocumentChanges = 4
            case allowsDocumentAssembly = 8
            case allowsContentCopying = 16
            case allowsContentAccessibility = 32
            case allowsCommenting = 64
            case allowsFormFieldEntry = 128
        }

         These are clearly bitfield values, so we return the combination
         of OR'd permissions that we want
         */

        return PDFAccessPermissions.allowsContentAccessibility.rawValue
    }
}
