/*
    pdfmaker
    main.swift

    Copyright © 2024 Tony Smith. All rights reserved.

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
let grabber: OutputGrabber = OutputGrabber.init()


// MARK: - Functions

func imagesToPdf() -> Bool {

    // Iterate through the source directory's files, or the named source file, adding
    // any JPEGs we find to the new PDF

    // Check the supplied paths
    // NOTE 'checkDirectory()' will exit if the either item doesn't exist
    let isSrcADir: Bool = checkDirectory(sourcePath, "Source")
    let isDestADir: Bool = checkDirectory(destPath, "Target")
    var filename: String

    // Determine the destination filename
    if isDestADir {
        // Destination path indicates a directory, so prepare the filename
        filename = getFilename(destPath, (outputName == nil ? "PDF From Images" : outputName!))
    } else {
        // Destination path indicates a file, so extract the filename
        // NOTE The file may not exist at this point -- we will make it later.
        filename = (destPath as NSString).lastPathComponent
        destPath = (destPath as NSString).deletingLastPathComponent

        // FROM 2.3.0 - Bug Fix
        // Ensure that the intermediate path is good
        _ = checkDirectory(destPath, "Target")

        // Assemble the file name that will be used
        // NOTE Add a number to the end to avoid replacement
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
    var gotFirstImage: Bool = false
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

        if doShowInfo {
            let extra: String = ext.count == 0 ? "ignoring" : "processing"
            writeToStderr("Found file: \(file), \(extra)")
        }

        // FROM 2.1.1
        // Support loading of PNG and TIFF as well as JPEG images
        let imageTypes: [String] = ["jpg", "jpeg", "png", "tiff", "tif"]
        if imageTypes.contains(ext) {
            // Load the image
            var image: NSImage? = NSImage.init(contentsOfFile: file)
            if image != nil {
                if doCompress && (ext == "jpg" || ext == "jpeg") {
                    // Re-compress the image
                    // NOTE Since we're loading from JPEG, the image may already by compressed
                    image = compressImage(image!)

                    // Break on error
                    if image == nil {
                        if doShowInfo { writeToStderr("Could not compress image \(file), ignoring") }
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
                            gotFirstImage = true
                            pdf = PDFDocument.init(data: pageData)
                            pageCount += 1
                        } else {
                            reportError("Could not add page \(pageCount) for image \(file)")
                        }
                    } else {
                        if let newpdf: PDFDocument = pdf {
                            // We're adding a page to the already created PDF,
                            // so just insert the page
                            gotFirstImage = true
                            newpdf.insert(page, at: pageCount)
                            pageCount += 1
                        } else {
                            reportError("Could not add page \(pageCount) for image \(file)")
                        }
                    }
                } else {
                    reportError("Could not create page for image \(file), ignoring")
                }
            } else {
                reportError("Could not load image \(file)")
            }
        }
    }

    // Did we add any images to the PDF?
    if gotFirstImage {
        // Yes we did, so save the PDF to disk
        if let newpdf: PDFDocument = pdf {
            if doShowInfo {
                writeToStderr("Writing PDF file \(savePath)")
            }
            
            // Did PDFKit complain?
            if pdfKitErr {
                processPdfKitErrors()
            }
            
            // Write the file to disk
            newpdf.write(toFile: savePath)
            return true
        }
    } else {
        if doShowInfo {
            writeToStderr("No suitable image files found in the source directory")
        }
    }

    return false
}


func processPdfKitErrors() {
    
    // FROM 2.3.7
    // Display PDFKit errors
    
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


func pdfToImages() -> Bool {

    // Check the supplied paths
    // NOTE 'checkDirectory()' will exit if the either item doesn't exist
    let isSrcADir: Bool = checkDirectory(sourcePath, "Source")
    let isDestADir: Bool = checkDirectory(destPath, "Target")

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
                    // free by the garbage collector after the loop has completed, but while looping,
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
                                    count += 1

                                    if doShowInfo {
                                        writeToStderr("Written image: \(path) of pixel size \(bmp.pixelsWide)x\(bmp.pixelsHigh)")
                                    }
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
            reportError("Could not load \(sourcePath)")
        }
    } else {
        reportError("Source \(sourcePath) is not a .pdf file")
    }

    return false
}


func getFilename(_ filepath: String, _ basename: String) -> String {

    // Run through the files in the specified directory ('filepath') and set
    // the output file's name so that it doesn't clash with existing files

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
    if newFilename.count > 255 {
        reportErrorAndExit("Generated filename \(newFilename) is too long -- please provide a filename")
    }

    // Send back the derived name
    return newFilename
}


func checkDirectory(_ path: String, _ dirType: String) -> Bool {

    // Check that item at 'path' is a directory or a regular file, returning
    // true or false, respectively. If the item is a file and it exists, we deal with
    // it later (in 'getFilename()'), but if it doesn't exist, we also return false
    // so that it can be created later.
    // NOTE 'dirType' is passed into the error report, if issued.
    //      It is the type of directory: 'Source' or 'Target'

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


func compressImage(_ image: NSImage) -> NSImage? {

    // Take an existing image, and compress it

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


func sizeAlign(_ dimension: CGFloat) -> CGFloat {

    // Ensure an image dimension, whether width or height, is an integral multiple of 2
    var returnValue: CGFloat = dimension.rounded(.down)

    if returnValue.truncatingRemainder(dividingBy: 2.0) != 0 {
        returnValue -= 1
    }

    return returnValue
}


func setDPI(_ imageRep: NSBitmapImageRep, _ dpi: CGFloat) {

    // Set the image DPI based on its pixel dimensions and the standard ('BASE') DPI

    var size: CGSize = imageRep.size
    size.width = CGFloat(imageRep.pixelsWide) * BASE_DPI / dpi
    size.height = CGFloat(imageRep.pixelsHigh) * BASE_DPI / dpi
    imageRep.size = size
}


func showCompression() {

    // Display the chosen image compression level
    let percent: Int = Int(compressionLevel * 100)
    var amount = "\(percent)%"
    if percent == 0 { amount = "Least (" + amount + ")" }
    if percent == 100 { amount = "Maxiumum (" + amount + ")" }
    writeToStderr("     Quality: " + amount)
}


func getFullPath(_ relativePath: String) -> String {

    // FROM 2.3.0
    // Convert a partial path to an absolute path

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


func processRelativePath(_ relativePath: String) -> String {

    // FROM 2.3.0
    // Add the basepath (the current working directory of the call) to the
    // supplied relative path - and then resolve it

    let absolutePath = FileManager.default.currentDirectoryPath + "/" + relativePath
    return (absolutePath as NSString).standardizingPath
}


func reportErrorAndExit(_ message: String, _ code: Int32 = EXIT_FAILURE) {

    // FROM 2.3.0
    // Generic error display routine that also quits the app

    writeToStderr(RED + BOLD + "ERROR" + RESET + " " + message + " -- exiting")
    dss.cancel()
    exit(code)
}


func reportError(_ message: String) {

    // FROM 2.3.0
    // Generic error display routine

    writeToStderr(RED + BOLD + "ERROR" + RESET + " " + message)
}


func reportWarning(_ message: String) {

    // FROM 2.3.7
    // Generic warning display routine

    writeToStderr(YELLOW + BOLD + "WARNING" + RESET + " " + message)
}


func writeToStderr(_ message: String) {

    // FROM 2.3.0
    // Write errors and other messages to stderr

    writeOut(message, STD_ERR)
}


func writeToStdout(_ message: String) {

    // FROM 2.3.2
    // Write errors and other messages to stderr

    writeOut(message, STD_OUT)
}


func writeOut(_ message: String, _ targetFileHandle: FileHandle) {

    // FROM 2.3.2
    // Write errors and other messages to `target`

    let messageAsString = message + "\r\n"
    if let messageAsData: Data = messageAsString.data(using: .utf8) {
        targetFileHandle.write(messageAsData)
    }
}


func showHelp() {

    // Display the help screen

    showHeader()

    writeToStdout("\nConvert a directory of images or a specified image to a single PDF file, or")
    writeToStdout("expand a single PDF file into a collection of image files.")
    writeToStdout(ITALIC + "https://github.com/smittytone/pdfmaker\n" + RESET)
    writeToStdout(BOLD + "USAGE" + RESET + "\n    pdfmaker [-s path] [-d path] [-c value] [-r value] [-b ] [-v] [-h]\n")
    writeToStdout(BOLD + "OPTIONS" + RESET)
    writeToStdout("    -s | --source      {path}    The path to the images or an image. Default: current folder")
    writeToStdout("    -d | --destination {path}    Where to save the new PDF. The file name is optional.")
    writeToStdout("                                 Default: ~/Desktop folder/\'PDF From Images.pdf\'.")
    writeToStdout("    -n | --name                  Specify the target file name. Only used when your destination")
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


func showVersion() {

    // FROM 2.1.0
    // Display the utility's version

    showHeader()
    writeToStdout("Copyright © 2024, Tony Smith (@smittytone).\r\nSource code available under the MIT licence.")
}


func showHeader() {

    // FROM 2.1.0
    // Display the utility's version number

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
var args = CommandLine.arguments
if args.count == 1 {
    showHelp()
    dss.cancel()
    exit(EXIT_SUCCESS)
}

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

// Convert the images
var success: Bool = doBreak ? pdfToImages() : imagesToPdf()
dss.cancel()
exit(success ? 0 : 1)
