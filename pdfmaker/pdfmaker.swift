/*
    pdfmaker
    pdf.swift

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


/*
 FROM 2.6.0
 */
private struct PdfLine {
    let text: String
    let bounds: CGRect
}


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
        let savePath = destPath + "/" + filename

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
        var pageCount = 0
        var pdfKitErr = false

        // Prepare a PDF Document
        let pdf: PDFDocument? = PDFDocument()

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
            let ext = (file as NSString).pathExtension.lowercased()

            reportInfo("Found file: \(file), \(ext.count == 0 ? "ignoring" : "processing")")

            // FROM 2.1.1
            // Support loading of PNG, JPG, HEIC, TIF, WEBP
            let supportedImageTypes = ["jpg", "jpeg", "png", "tiff", "tif", "heic", "webp", "bmp"]
            if supportedImageTypes.contains(ext) {
                // Load the image
                var image: NSImage? = NSImage(contentsOfFile: file)
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
                    if let page = PDFPage(image: image!) {
                        // FROM 2.5.0
                        // Don't clear `pdfKitErr` if `closeConsolePipe()` returns `false` on subsequent run
                        if grabber.closeConsolePipe(), !pdfKitErr {
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

                // FROM 2.5.0
                // If metadata has been set, apply it to the PDFDocument
                if newpdf.documentAttributes != nil {
                    if !metadata.title.isEmpty {
                        newpdf.documentAttributes![PDFDocumentAttribute.titleAttribute] = metadata.title
                    }

                    if !metadata.subject.isEmpty {
                        newpdf.documentAttributes![PDFDocumentAttribute.subjectAttribute] = metadata.subject
                    }

                    if !metadata.author.isEmpty {
                        newpdf.documentAttributes![PDFDocumentAttribute.authorAttribute] = metadata.author
                    }

                    // Set the standard creator
                    newpdf.documentAttributes![PDFDocumentAttribute.creatorAttribute] = "pdfmaker " + getVersion(withBuild: false)
                }

                // Write the file to disk
                if !metadata.password.isEmpty {
                    // FROM 2.5.0
                    // If a password has been set, apply it as the admin password to the PDFDocument
                    // NOTE Only apply access permissions for encrypted docs
                    newpdf.write(toFile: savePath, withOptions: [
                        .ownerPasswordOption: metadata.password,
                        .accessPermissionsOption: setPermissions()
                    ])
                } else {
                    // Or, as before, just write an unencrypted PDF
                    newpdf.write(toFile: savePath)
                }

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
        let ext = (sourcePath as NSString).pathExtension.lowercased()

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
            let scaleFactor = outputResolution == BASE_DPI ? 1.0 : outputResolution / BASE_DPI
            let imageProps: [NSBitmapImageRep.PropertyKey: Any] = [NSBitmapImageRep.PropertyKey.compressionFactor: compressionLevel]
            var count = 0

            // Load and process the PDF
            do {
                // Get the PDF as data and convert it to a PDF Image Representation
                let fileData = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
                if let pdfRep = NSPDFImageRep(data: fileData) {
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
                            let newSize = CGSize.init(width: newWidth, height: newHeight)
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
                                if scaleFactor != 1.0 { setDPI(bmp, outputResolution) }

                                // Convert the image to JPEG and save to disk
                                if let finalData = bmp.representation(using: .jpeg, properties: imageProps) {
                                    let path = destPath + "/page " + String(format: "%03d", i + 1) + ".jpg"
                                    do {
                                        try finalData.write(to: URL(fileURLWithPath: path))
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
        let ext = URL(fileURLWithPath: sourcePath).pathExtension

        // Only proceed if the file is a PDF
        if ext == "pdf" {
            do {
                // Get data from the file...
                let fileData = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
                // FROM 2.6.0
                var paragraphs: [String] = []

                // ...and see if it's a PDF
                if let pdf = PDFDocument(data: fileData) {
                    // Error 'CoreGraphics PDF has logged an error... Invalid image orientation, assuming 1'
                    // generated by the next call
                    grabber.openConsolePipe()

                    // Extract the text from each page as an NSAttributedString
                    for i in 0 ..< pdf.pageCount {
                        guard let page = pdf.page(at: i) else { continue }

                        // FROM 2.6.0
                        // Make a selection of characters from the page
                        guard page.numberOfCharacters > 0, let pageSelection = page.selection(for: NSRange(location: 0, length: page.numberOfCharacters)) else { continue }
                        
                        // Convert the selection into lines of text and the area of the page
                        // encompassed by the text. We'll use this to estimate which lines
                        // comprise paragraphs
                        var lines: [PdfLine] = []
                        for lineSelection in pageSelection.selectionsByLine() {
                            guard let text = lineSelection.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { continue }
                            let line = PdfLine(text: text, bounds: lineSelection.bounds(for: page).standardized)
                            lines.append(line)
                        }

                        // Convert the line data to an array of paragraphs
                        Pdf.constructParagraphs(from: lines, to: &paragraphs)
                    }

                    _ = grabber.closeConsolePipe()

                    // FROM 2.6.0
                    // Assemble the final paragraphs by checking for those that span page breaks
                    // (and so will appear as separate paragraphs) and so should be joined
                    var previous = ""
                    var joinedParagraphs: [String] = []
                    for paragraph in paragraphs {
                        if !previous.isEmpty {
                            if let initial = paragraph.first, !initial.isUppercase {
                                joinedParagraphs.append(previous + " " + paragraph)
                                previous = ""
                                continue
                            }
                        }

                        if !paragraph.hasSuffix(".") {
                            previous = paragraph
                        } else {
                            joinedParagraphs.append(paragraph)
                        }
                    }

                    let combined = joinedParagraphs.joined(separator: "\n\n")

                    // If we have gathered some text, output it to a file
                    if !combined.isEmpty {
                        if let finalData = combined.data(using: .utf8) {
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
        var newBasename = basename

        let pathExt = (newBasename as NSString).pathExtension.lowercased()
        if pathExt == "pdf" {
            newBasename = (newBasename as NSString).deletingPathExtension
        } else if pathExt != "" {
            // NOT a PDF file, so bail
            Stdio.reportErrorAndExit("\(newBasename) does not reference a PDF file")
        }

        // Assemble the target filename
        var newFilename = newBasename + ".pdf"
        var i = 0

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
        let success = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if success {
            // The path points to an existing item, so return its type
            return isDir.boolValue
        }

        // Is the non-existent item a file, ie. does it have an extension?
        let ext = (path as NSString).pathExtension

        if ext.count > 0 {
            // There is an extension, so assume it points to a file,
            // which we will create later
            return false
        }

        // FROM 2.3.0
        // Try and make intermediate directories if we can and are asked to
        if doMakeSubDirectories {
            do {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: path),
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


    /**
     Display the chosen image compression level.
     */
    static func showCompression() {

        let percent = Int(compressionLevel * 100)
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
    static func setDPI(_ imageRep: NSBitmapImageRep, _ dpi: CGFloat) {

        var size = imageRep.size
        size.width = CGFloat(imageRep.pixelsWide) * BASE_DPI / dpi
        size.height = CGFloat(imageRep.pixelsHigh) * BASE_DPI / dpi
        imageRep.size = size
    }


    /**
     Report information, if requested by the user.
     */
    static func reportInfo(_ message: String) {

        if doShowInfo {
            Stdio.report(withEmoji: "✅", message)
        }
    }


    static private func setPermissions() -> UInt {

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


    /**
     Construct a putative sequence of paragraphs from a series of lines.

     - Parameters:
        - from: An array of lines (as text and bounds in the PDF).
        - to:   A pointer to the array of paragraphs to assemble.
     */
    private static func constructParagraphs(from lines: [PdfLine], to paragraphs: inout [String]) {

        // No line to process? We're all done.
        guard !lines.isEmpty else { return }

        // Determine the gaps between lines: large gaps are indicative
        // of paragraph breaks
        let gaps = zip(lines, lines.dropFirst())
            .map { current, next in
                max(0, current.bounds.minY - next.bounds.maxY)
            }
            .filter { $0 > 0 }

        let normalGap = median(gaps)

        // Get a typical right edge for normal, full-width lines.
        let rightEdges = lines.map(\.bounds.maxX).sorted()
        let typicalRightEdge = rightEdges[rightEdges.count * 3 / 4]

        var paragraph = ""
        for index in lines.indices {
            append(lines[index].text, to: &paragraph)

            // If we're at the last line in a paragraph,
            // add the assembled paragraph to the array and
            // move on to the next line of text
            if index == lines.index(before: lines.endIndex) {
                paragraphs.append(paragraph)
                continue
            }

            let currentLine = lines[index]
            let nextLine = lines[index + 1]

            // Check for a break between the current and following lines.
            // Store the current paragraph if that's the case, and prep a new one.
            if isParagraphBreak(currentLine, nextLine, normalGap, typicalRightEdge) {
                paragraphs.append(paragraph)
                paragraph = ""
            }
        }
    }


    /**
     Determine whether there is a paragraph break between the current line and the next one.

     Run of a series of checks, in order of likelihood that they indicate a paragraph break.

     - Parameters:
        - current:          The current line as a PdfLine instance (text plus page bounds).
        - next:             The next line as a PdfLine instance.
        - normalGap:        The median distance between lines in the PDF.
        - typicalRightEdge: The distance between the page edge (bounds) and the start of un-indented text.

     - Returns: `true` if it looks like the two lines are parts of different paragraphs,
                otherwise `false`.
     */
    private static func isParagraphBreak(_ current: PdfLine, _ next: PdfLine, _ normalGap: CGFloat, _ typicalRightEdge: CGFloat) -> Bool {

        // A larger-than-normal vertical gap is the strongest signal
        // of a gap between paragraphs
        let verticalGap = max(0, current.bounds.minY - next.bounds.maxY)
        if verticalGap > max(3, normalGap * 1.7) {
            return true
        }

        // Bullets and numbered items normally begin new paragraphs
        if isListItem(next.text) {
            return true
        }

        // Detect a first-line indent, but avoid treating a wrapped list
        // item's hanging indent as a new paragraph.
        let indentation = next.bounds.minX - current.bounds.minX
        if indentation > max(8, current.bounds.height * 0.75), !isListItem(current.text) {
            return true
        }

        // A short line ending with punctuation is likely the last line of a paragraph
        let unusedWidth = typicalRightEdge - current.bounds.maxX
        let isShort = unusedWidth > current.bounds.height * 2
        let endsSentence = current.text.range(of: #"[.!?][”’"')\]]*$"#, options: .regularExpression) != nil
        return isShort && endsSentence
    }


    /**
     Add a line of text to an existing paragraph.

     - Parameters:
        - line: The current line's text
        - to:   The paragraph string the line may be added to.
     */
    private static func append(_ line: String, to paragraph: inout String) {

        guard !paragraph.isEmpty else {
            paragraph = line
            return
        }

        // Optionally repair words hyphenated across visual lines.
        // NOTE This will catch some genuinely hyphenated words that span lines.
        if paragraph.hasSuffix("-"), line.first?.isLowercase == true {
            paragraph.removeLast()
            paragraph += line
        } else {
            paragraph += " " + line
        }
    }


    /**
     Determine whether a line of text is a bullet point or number item.

     - Parameters:
        - text: The line to check.

     - Returns: `true` if it appears the line is a list item, otherwise `false`.
     */
    private static func isListItem(_ text: String) -> Bool {

        text.range(
            of: #"^(?:[•▪◦-]\s+|\d+[.)]\s+|[A-Za-z][.)]\s+)"#,
            options: .regularExpression
        ) != nil
    }


    /**
     Determine the median of a series of values.

     - Parameters:
        - values: An array of floating-point values.

     - Returns: The median value.
     */
    private static func median(_ values: [CGFloat]) -> CGFloat {

        guard !values.isEmpty else { return 0 }

        let sorted = values.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }

}
