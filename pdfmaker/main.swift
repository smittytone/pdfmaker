/*
    pdfmaker
    main.swift

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


// MARK: - Constants

// FROM 2.0.0
let BASE_DPI: CGFloat    = 72.0
let DEFAULT_DPI: CGFloat = 300.0

// FROM 2.3.0 -- Use stderr, stdout for output
let STD_ERR: FileHandle = FileHandle.standardError
let STD_OUT: FileHandle = FileHandle.standardOutput

// FROM 2.3.0 -- TTY formatting
let RED: String             = "\u{001B}[0;31m"
let YELLOW: String          = "\u{001B}[0;33m"
let RESET: String           = "\u{001B}[0m"
let BOLD: String            = "\u{001B}[1m"
let ITALIC: String          = "\u{001B}[3m"
let BSP: String             = String(UnicodeScalar(8))
// FROM 2.3.1
let EXIT_CTRL_C_CODE: Int32 = 130
let CTRL_C_MSG: String      = "\(BSP)\(BSP)\rpdfmaker interrupted -- halting"


// MARK: - Global Variables

// CLI argument management
var argIsAValue: Bool = false
var argType: Int      = -1
var argCount: Int     = 0
var prevArg: String   = ""

// PDF processing variables
var destPath: String          = "~/Desktop"
var outputName: String?       = nil
var sourcePath: String        = FileManager.default.currentDirectoryPath
var doCompress: Bool          = false
var compressionLevel: CGFloat = 0.8
var doShowInfo: Bool          = false

// FROM 2.0.0
var doBreak: Bool = false
var outputResolution: CGFloat = BASE_DPI

// FROM 2.3.0
var doMakeSubDirectories: Bool = false
var isPiped: Bool = false

// FROM 2.3.7
let grabber: OutputGrabber = OutputGrabber.init(dedupe: true)


// MARK: - Functions

///
/// Convert a set of images to a PDF. Images must be of supported types:
/// currently PNG, JPG, TIF.
///
/// - Parameters:
///     - isSrcADir  Does the global source file path lead to a directory?
///     - isDestADir Does the global destination file path lead to a directory?
///
/// - Returns `true` on a successful completion, otherwise `false`.
///
func imagesToPdf(_ isSrcADir: Bool, _ isDestADir: Bool) -> Bool {

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
        writeToStderr("Attempting to assemble \(savePath) from \(sourcePath)...")
        if doCompress { showCompression() }
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
            reportError("Unable to get contents of directory \(sourcePath)")
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
                        reportWarning("Could not compress image \(file), ignoring")
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
                            reportError("Could not add page \(pageCount) for image \(file)")
                        }
                    } else {
                        if let newpdf: PDFDocument = pdf {
                            // We're adding a page to the already created PDF,
                            // so just insert the page
                            newpdf.insert(page, at: pageCount)
                            pageCount += 1
                        } else {
                            reportError("Could not add page \(pageCount) for image \(file)")
                        }
                    }
                } else {
                    reportError("Could not create page for image \(file)")
                }
            } else {
                reportError("Could not load image \(file)")
            }
        } else {
            reportWarning("File \(file) is not a supported image type, ignoring")
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
        reportWarning("No suitable image files found in the source directory")
    }

    return false
}


///
/// Display errors generated directly by PDFKit.
///
/// PDFKit issues file errors directly to `STDERR`, so we trap these elsewhere
/// (see `output-grabber.swift` and here de-dupe the errors from PDFKit and
/// output the remaining errors.
///
/// FROM 2.3.7
///
func processPdfKitErrors() {
    
    if doShowInfo || grabber.verboseErrSet {
        // List all the errors if we're in pdfmaker verbose mode,
        // or the `CG_PDF_VERBOSE` env var has been set
        var errString: String = ""
        for (index, error) in grabber.errors.enumerated() {
            errString += "“" + error + "” (Count: \(grabber.errorCounts[index])), "
        }
        
        if !errString.isEmpty {
            reportWarning("PDFKit issued these messages: \(errString[errString.startIndex...errString.index(errString.endIndex, offsetBy: -2)])")
        }
    } else {
        // Issue a base warning
        reportWarning("PDFKit grumbled about one or more images. For more information, set the environment variable CG_PDF_VERBOSE before running pdfmaker next time")
    }
}


///
/// Convert a PDF files to a set of images.
///
/// - Parameters:
///     - isSrcADir  Does the global source file path lead to a directory?
///     - isDestADir Does the global destination file path lead to a directory?
///
/// - Returns `true` on a successful completion, otherwise `false`.
///
func pdfToImages(_ isSrcADir: Bool, _ isDestADir: Bool) -> Bool {

    // Make sure we're loading a PDF and outputting to a directory
    if !isDestADir {
        reportError("Chosen image destination \(destPath) is not a directory")
        return false
    }

    if isSrcADir {
        reportError("Source \(sourcePath) is a directory")
        return false
    }

    // Get the file extension
    let ext: String = (sourcePath as NSString).pathExtension.lowercased()

    // Only proceed if the file is a PDF
    if ext == "pdf" {
        // Output info, if requested to do so
        if doShowInfo {
            // We're in verbose mode, so show some info
            writeToStderr("Attempting to disassemble \(sourcePath) to \(destPath)...")
            if doCompress { showCompression() }
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
                                    reportError("Could not write file \(path)")
                                }
                            } else {
                                reportError("Could not create an image for \(sourcePath) page \(i)")
                            }
                        }
                    }
                }

                if count > 0 { return true }
            } else {
                reportError("Could not extract the PDF data from \(sourcePath)")
            }
        } catch {
            reportError("Could not load file \(sourcePath)")
        }
    } else {
        reportError("Source \(sourcePath) is not a .pdf file")
    }

    return false
}


///
/// Run through the files in the specified directory and set the output
/// file's name so that it doesn't clash with existing files. For example,
/// if `Untitled.pdf` exists, this will generate `Untitled 01.pdf`
///
/// - Parameters:
///     - filepath The directory's path.
///     - basename The base output filename to which integers will be appended.
///
/// - Returns: The new file name, or the existing one if it's OK.
///
func getFilename(_ filepath: String, _ basename: String) -> String {

    // If the passed filename has a '.pdf' extension, remove it
    var newBasename: String = basename

    let pathExt: String = (newBasename as NSString).pathExtension.lowercased()
    if pathExt == "pdf" {
        newBasename = (newBasename as NSString).deletingPathExtension
    } else if pathExt != "" {
        // NOT a PDF file, so bail
        reportErrorAndExit("\(newBasename) does not reference a PDF file")
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
        reportErrorAndExit("Generated filename \(newFilename) is too long -- please provide a filename")
    }

    // Send back the derived name
    return newFilename
}


///
/// Check whether the item at the provided path is a directory or a regular file.
///
/// - Parameters:
///     - path    A path to a file or directory, existent or non-existent.
///     - dirType Whether the path leads to a source or target entity.
///
/// - Returns: `true` if the file is an existing directory, `false` if it's a file,
///            a non-existent file, or a non-existent directory that can't be created/
///
func checkDirectory(_ path: String, _ dirType: String) -> Bool {

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
            reportErrorAndExit("\(dirType) directory \(path) does not exist and cannot be created")
        }
    } else {
        reportErrorAndExit("\(dirType) directory \(path) does not exist. Use the --createdirs switch")
    }

    return true
}


///
/// Compress an image.
///
/// - Parameters:
///     - image The chosen image.
///
/// - Returns: The compressed image, or `nil` on error.
///
func compressImage(_ image: NSImage) -> NSImage? {

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


///
/// Ensure an image dimension, whether width or height, is an integral multiple of 2.
///
/// - Parameters:
///     - dimension The chosen base (width or height)
///
/// - Returns: The dimension's closest even value.
///
func sizeAlign(_ dimension: CGFloat) -> CGFloat {

    var returnValue: CGFloat = dimension.rounded(.down)

    if returnValue.truncatingRemainder(dividingBy: 2.0) != 0 {
        returnValue -= 1
    }

    return returnValue
}


///
/// Set the image DPI based on its pixel dimensions and the standard ('BASE') DPI.
///
/// - Parameters:
///     - imageRep The image for which the DPI will be set.
///     - dpi      The required DPI.
///
func setDPI(_ imageRep: NSBitmapImageRep, _ dpi: CGFloat) {

    var size: CGSize = imageRep.size
    size.width = CGFloat(imageRep.pixelsWide) * BASE_DPI / dpi
    size.height = CGFloat(imageRep.pixelsHigh) * BASE_DPI / dpi
    imageRep.size = size
}


///
/// Display the chosen image compression level.
///
func showCompression() {

    let percent: Int = Int(compressionLevel * 100)
    var amount = "\(percent)%"
    if percent == 0 { amount = "Least (" + amount + ")" }
    if percent == 100 { amount = "Maxiumum (" + amount + ")" }
    writeToStderr("     Quality: " + amount)
}


///
/// Convert a partial path to an absolute path.
/// FROM 2.3.0
///
/// - Parameters:
///     - relativePath A path.
///
/// - Returns: An absolute path.
///
func getFullPath(_ relativePath: String) -> String {

    // Standardise the path as best as we can (this covers most cases)
    var absolutePath: String = (relativePath as NSString).standardizingPath

    // Check for a unresolved relative path -- and if it is one, resolve it
    // NOTE This includes raw filenames
    if (absolutePath as NSString).contains("..") || !(absolutePath as NSString).hasPrefix("/") {
        absolutePath = processRelativePath(absolutePath)
    }

    // Return the absolute path
    return absolutePath
}


///
/// Add the basepath (the current working directory of the call) to the
/// supplied relative path - and then resolve it.
/// FROM 2.3.0
///
/// - Parameters:
///     - relativePath A path.
///
/// - Returns: An absolute path.
///
func processRelativePath(_ relativePath: String) -> String {

    let absolutePath = FileManager.default.currentDirectoryPath + "/" + relativePath
    return (absolutePath as NSString).standardizingPath
}


///
/// Generic error display routine that also quits the app.
/// FROM 2.3.0
///
/// - Parameters:
///     - message The text to print.
///     - code    The shell `exit` error code.
///
func reportErrorAndExit(_ message: String, _ code: Int32 = EXIT_FAILURE) {

    writeToStderr(RED + BOLD + "ERROR" + RESET + " " + message + " -- exiting")
    dss.cancel()
    exit(code)
}


///
/// Generic warning display routine.
/// FROM 2.3.0
///
/// - Parameters:
///     - message The text to print.
///
func reportError(_ message: String) {

    writeToStderr(RED + BOLD + "ERROR" + RESET + " " + message)
}


///
/// Generic warning display routine.
/// FROM 2.3.7
///
/// - Parameters:
///     - message The text to print.
///
func reportWarning(_ message: String) {

    writeToStderr(YELLOW + BOLD + "WARNING" + RESET + " " + message)
}


///
/// Post extra information but only if requested by the user.
/// FROM 2.3.8
///
/// - Parameters:
///     - message The text to print.
///
func reportInfo(_ message: String) {
    
    if doShowInfo {
        writeToStderr(message)
    }
}


///
/// Issue the supplied text to `STDERR`.
///
/// - Parameters:
///     - message The text to print.
///
func writeToStderr(_ message: String) {

    writeOut(message, STD_ERR)
}


///
/// Issue the supplied text to `STDOUT`.
///
/// - Parameters:
///     - message The text to print.
///
func writeToStdout(_ message: String) {

    writeOut(message, STD_OUT)
}


///
/// Generic text output routine.
/// FROM 2.3.2
///
/// - Parameters:
///     - message           The text to print.
///     - targetFileHandle: Where the message will be sent.
///
func writeOut(_ message: String, _ targetFileHandle: FileHandle) {

    let messageAsString = message + "\r\n"
    if let messageAsData: Data = messageAsString.data(using: .utf8) {
        targetFileHandle.write(messageAsData)
    }
}


///
/// Display the help screen.
///
func showHelp() {

    showHeader()

    writeToStdout("\nConvert a directory of images or a specified image to a single PDF file, or")
    writeToStdout("expand a single PDF file into a collection of image files.")
    writeToStdout(ITALIC + "https://github.com/smittytone/pdfmaker\n" + RESET)
    writeToStdout(BOLD + "USAGE" + RESET + "\n    pdfmaker [-s path] [-d path] [-c value] [-r value] [-b ] [-v] [-h]\n")
    writeToStdout(BOLD + "OPTIONS" + RESET)
    writeToStdout("    -s | --source      {path}    The path to the images or an image. Default: current folder")
    writeToStdout("    -d | --destination {path}    Where to save the new PDF. The file name is optional.")
    writeToStdout("                                 Default: ~/Desktop folder/\'PDF From Images.pdf\'.")
    writeToStdout("    -n | --name        {name}    Specify the target file name. Only used when your destination")
    writeToStdout("                                 is a directory.")
    writeToStdout("    -c | --compress    {amount}  Apply an image compression filter to the PDF:")
    writeToStdout("                                 0.0 = maximum compression, lowest image quality.")
    writeToStdout("                                 1.0 = no compression, best image quality.")
    writeToStdout("         --createdirs            Make target intermediate directories if they do not exist.")
    writeToStdout("    -b | --break                 Break a PDF into JPEG images.")
    writeToStdout("    -r | --resolution  {dpi}     The output resolution of extracted images. Max: 9999.")
    writeToStdout("    -v | --verbose               Show progress information. Otherwise only errors are shown.")
    writeToStdout("    -h | --help                  This help screen.")
    writeToStdout("         --version               Show pdfmaker version information.\n")
    writeToStdout(BOLD + "EXAMPLES" + RESET)
    writeToStdout("    pdfmaker --source $IMAGES_DIR --destination $PDFS_DIR/\'Project X.pdf\' --compress 0.8")
    writeToStdout("    pdfmaker --source $IMAGES_DIR/cover.jpg --destination $PDFS_DIR --compress 0.5")
    writeToStdout("    pdfmaker --break --source $PDFS_DIR/\'Project X.pdf\' --destination $IMAGES_DIR\n")
}


///
/// Display the app's version and other information.
/// FROM 2.1.0
///
func showVersion() {

    showHeader()
    writeToStdout("Copyright © 2025, Tony Smith (@smittytone).\r\nSource code available under the MIT licence.")
}


///
/// Display the app's version.
/// FROM 2.1.0
///
func showHeader() {

    let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    let name:String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    writeToStdout("\(name) \(version) (\(build))")
}



// MARK: - Runtime Start

// FROM 2.3.2
// Make sure the signal does not terminate the application
signal(SIGINT, SIG_IGN)

// Set up an event source for SIGINT...
let dss: DispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGINT,
                                                                queue: DispatchQueue.main)
// ...add an event handler (from above)...
dss.setEventHandler {
    writeToStderr(CTRL_C_MSG)
    dss.cancel()
    exit(EXIT_CTRL_C_CODE)
}

// ...and start the event flow
dss.resume()

// FROM 2.3.0
// No arguments? Show Help
if CommandLine.arguments.count == 1 {
    showHelp()
    dss.cancel()
    exit(EXIT_SUCCESS)
}

// Expand composite flags
var args: [String] = []
for arg in CommandLine.arguments {
    // Look for compound flags, ie. a single dash followed by
    // more than one flag identifier
    if arg.prefix(1) == "-" && arg.prefix(2) != "--" {
        if arg.count > 2 {
            // arg is of form '-mfs'
            for sub_arg in arg {
                // Check for and ignore interior dashes
                // eg. in `-mf-l`
                if sub_arg == "-" {
                    continue
                }
                
                // Retain the flag as a standard arg for subsequent processing
                args.append("-\(sub_arg)")
            }

            continue
        }
    }
    
    // It's an ordinary arg, so retain it
    args.append(arg)
}

// Process the (separated) arguments
for argument in args {
    // Ignore the first comand line argument
    if argCount == 0 {
        argCount += 1
        continue
    }

    if argIsAValue {
        // Make sure we're not reading in an option rather than a value
        if argument.prefix(1) == "-" {
            reportErrorAndExit("Missing value for \(prevArg)")
        }

        switch argType {
        case 0:
            destPath = argument
        case 1:
            sourcePath = argument
        case 2:
            outputName = argument
        case 3:
            doCompress = true
            if let cl = Float(argument) {
                compressionLevel = CGFloat(cl)
            }

            // FROM 2.3.0 -- check values!
            if compressionLevel < 0.0 || compressionLevel > 1.0 {
                reportErrorAndExit("Compression level out of range")
            }
        case 4:
            if let rs = Float(argument) {
                outputResolution = CGFloat(rs)
            }

            // FROM 2.3.0 -- check values!
            if outputResolution < 1 || outputResolution > 9999 {
                reportErrorAndExit("Output resolution out of range")
            }
        default:
            reportErrorAndExit("Unknown argument: \(argument)")
        }

        argIsAValue = false
    } else {
        switch argument {
        case "-d":
            fallthrough
        case "--destination":
            argType = 0
            argIsAValue = true
        case "-s":
            fallthrough
        case "--source":
            argType = 1
            argIsAValue = true
        case "-n":
            fallthrough
        case "--name":
            argType = 2
            argIsAValue = true
        case "-c":
            fallthrough
        case "--compress":
            argType = 3
            argIsAValue = true
        case "-r":
            fallthrough
        case "--resolution":
            argType = 4
            argIsAValue = true
        case "-b":
            fallthrough
        case "--break":
            doBreak = true
        case "--createdirs":
            doMakeSubDirectories = true
        case "-v":
            fallthrough
        case "--verbose":
            doShowInfo = true
        case "-h":
            fallthrough
        case "--help":
            showHelp()
            exit(EXIT_SUCCESS)
        case "--version":
            showVersion()
            exit(EXIT_SUCCESS)
        default:
            reportErrorAndExit("Unknown argument: \(argument)")
        }

        prevArg = argument
    }

    argCount += 1

    // Trap commands that come last and therefore have missing args
    if argCount == CommandLine.arguments.count && argIsAValue {
        reportErrorAndExit("Missing value for \(argument)")
    }
}

// FROM 2.3.0
// Fix source and destination paths here, not if they were set
// (so we catch the defaults)
destPath = getFullPath(destPath)
sourcePath = getFullPath(sourcePath)

// Check the supplied paths
// NOTE 'checkDirectory()' will exit if the either item doesn't exist
let isSrcADir: Bool = checkDirectory(sourcePath, "Source")
let isDestADir: Bool = checkDirectory(destPath, "Target")

// Convert the images
var success: Bool = doBreak ? pdfToImages(isSrcADir, isDestADir) : imagesToPdf(isSrcADir, isDestADir)
dss.cancel()
exit(success ? 0 : 1)
