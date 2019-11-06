//
//  main.swift
//  pdfmaker
//
//  Created by Tony Smith on 16/10/2019.
//  Copyright © 2019 Tony Smith. All rights reserved.
//


import Foundation
import Quartz


// MARK: - Constants

// FROM 2.0.0
let BASE_DPI: CGFloat = 72.0
let DEFAULT_DPI: CGFloat = 300.0


// MARK: - Global Variables

var argIsAValue: Bool = false
var argType: Int = -1
var argCount: Int = 0
var prevArg: String = ""
var destPath: String = "~/Desktop"
var outputName: String? = nil
var sourcePath: String = FileManager.default.currentDirectoryPath
var doCompress: Bool = false
var compressionLevel: CGFloat = 0.8
var doShowInfo: Bool = false

// FROM 2.0.0
var doBreak: Bool = false
var outputResolution: CGFloat = BASE_DPI


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
        filename = getFilename(destPath, filename)
    }
    
    // Set the destination path from the generated filename
    let savePath: String = destPath + "/" + filename
    
    if doShowInfo {
        // We're in verbose mode, so show some info
        print("Conversion Information")
        print("Image Source: \(sourcePath)")
        print("  Target PDF: \(savePath)")

        if doCompress {
            showCompression()
        }

        print("Attempting to assemble PDF file...")
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
            print("[ERROR] Unable to get contents of directory")
            return false
        }
    } else {
        // 'srcDir' points to a file, so add it to files array manually
        files = [sourcePath]
    }

    // Initialise counters and flags
    var gotFirstImage: Bool = false
    var pageCount: Int = 0

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
            print("Found file: \(file)... \(extra)")
        }

        // Only proceed if the file is a JPEG
        if ext == "jpg" || ext == "jpeg" {
            // Load the image
            var image: NSImage? = NSImage.init(contentsOfFile: file)
            if image != nil {
                if doCompress {
                    // Re-compress the image
                    // NOTE Since we're loading from JPEG, the image may already by compressed
                    image = compressImage(image!)

                    // Break on error
                    if image == nil {
                        if doShowInfo { print("Could not compress image... ignoring") }
                        break
                    }
                }

                // Create a PDF page based on the image
                let page: PDFPage? = PDFPage.init(image: image!)
                if page != nil {
                    // FROM 1.1.2
                    // Set the mediaBox size
                    page!.setBounds(CGRect.init(x: 0, y: 0, width: image!.size.width, height: image!.size.height), for: .mediaBox)

                    if pageCount == 0 {
                        // This will be the first page in the PDF, so initialize
                        // the PDF will the page data
                        if let pageData: Data = page!.dataRepresentation {
                            gotFirstImage = true
                            pdf = PDFDocument.init(data: pageData)
                            pageCount += 1
                        }
                    } else {
                        if let newpdf: PDFDocument = pdf {
                            // We're adding a page to the already created PDF,
                            // so just insert the page
                            gotFirstImage = true
                            newpdf.insert(page!, at: pageCount)
                            pageCount += 1
                        }
                    }
                }
            } else {
                print("[ERROR] Could not load image for file \(file)")
            }
        }
    }

    // Did we add any images to the PDF?
    if gotFirstImage {
        // Yes we did, so save the PDF to disk
        if let newpdf: PDFDocument = pdf {
            if doShowInfo { print("Writing PDF file \(savePath)") }
            newpdf.write(toFile: savePath)
            return true
        }
    } else {
        if doShowInfo {
            print("No suitable image files found in the source directory")
        }
    }

    return false
}


func pdfToImages() -> Bool {

    // Check the supplied paths
    // NOTE 'checkDirectory()' will exit if the either item doesn't exist
    let isSrcADir: Bool = checkDirectory(sourcePath, "Source")
    let isDestADir: Bool = checkDirectory(destPath, "Target")

    // Make sure we're loading a PDF and outputting to a directory
    if !isDestADir {
        print("[ERROR] Chosen image destination \(destPath) is not a directory")
        return false
    }

    if isSrcADir {
        print("[ERROR] Source \(destPath) is a directory")
        return false
    }

    // Get the file extension
    let ext: String = (sourcePath as NSString).pathExtension.lowercased()

    // Only proceed if the file is a PDF
    if ext == "pdf" {
        // Output info, if requested to do so
        if doShowInfo {
            // We're in verbose mode, so show some info
            print("Conversion Information")
            print("  Source PDF: \(sourcePath)")
            print("      Images: \(destPath)")

            if doCompress {
                showCompression()
            }

            print("Attempting to disassemble PDF file...")
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

                        // Convert the NSImage to data, then to an image Rep and this to a JPEG we can save
                        var createFailed: Bool = false
                        if let imageData: Data = scaledImage.tiffRepresentation {
                            if let bmp: NSBitmapImageRep = NSBitmapImageRep.init(data: imageData) {
                                // Set the DPI to 'outputResolution'
                                if scaleFactor != 1.0 {
                                    setDPI(bmp, outputResolution)
                                }

                                // Convert the image to JPEG and save to disk
                                if let finalData: Data = bmp.representation(using: .jpeg, properties: imageProps) {
                                    let path: String = destPath + "/page " + String(format: "%03d", i + 1) + ".jpg"
                                    do {
                                        try finalData.write(to: URL.init(fileURLWithPath: path))
                                        count += 1

                                        if doShowInfo {
                                            print("Written image: \(path)")
                                        }
                                    } catch {
                                        print("[ERROR] Could not write file \(path)")
                                    }
                                } else {
                                    createFailed = true
                                }
                            } else {
                                createFailed = true
                            }
                        }

                        if createFailed {
                            print("[ERROR] Could not create an image for \(sourcePath) page \(i)")
                        }
                    }
                }

                if count > 0 {
                    return true
                }
            } else {
                print("[ERROR] Could not extract the PDF data from \(sourcePath)")
            }
        } catch {
            print("[ERROR] Could not load \(sourcePath)")
        }
    } else {
        print("[ERROR] Source \(sourcePath) is not a .pdf file")
    }

    return false
}


func getFilename(_ filepath: String, _ basename: String) -> String {

    // Run through the files in the specified directory ('filepath') and set
    // the output file's name so that it doesn't clash with existing files

    // If the passed filename has a '.pdf' extension, remove it
    var newBasename: String = basename
    if (newBasename as NSString).pathExtension.lowercased() == "pdf" {
        newBasename = (newBasename as NSString).deletingPathExtension
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

    // Send back the derived name
    return newFilename
}


func checkDirectory(_ path: String, _ dirType: String) -> Bool {

    // Check that item at 'path' is a directory or a regular file, returning
    // true or false, respectively. If the item is a file and it exists, we deal with
    // it later (in 'getFilename()'), but if it doesn't exist, we also return false
    // so that it can be created later.
    // NOTE 'dirType' is passed into the error report, if issued

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

    // A directory was specified but we can't find it so warn and bail
    // TODO Add a switch to make this missing directory
    print("[ERROR] \(dirType) directory \(path) does not exist")
    exit(1)
}


func compressImage(_ image: NSImage) -> NSImage? {

    // Take an existing image, and compress it
    // See https://stackoverflow.com/questions/52709210/how-to-compress-nsimage-in-swift-4
    if let tiff = image.tiffRepresentation {
        if let imageRep: NSBitmapImageRep = NSBitmapImageRep(data: tiff) {
            let compressedData = imageRep.representation(using: NSBitmapImageRep.FileType.jpeg,
                                                         properties: [NSBitmapImageRep.PropertyKey.compressionFactor : compressionLevel])!
            return NSImage(data: compressedData)
        }
    }

    // Something went wrong, so just return nil
    return nil
}


func sizeAlign(_ dimension: CGFloat) -> CGFloat {

    // Ensure an image dimension ('d'), whether width or height, is a multiple of 10

    var returnValue: CGFloat = 0.0
    let remainder: CGFloat = dimension.truncatingRemainder(dividingBy: 10.0)

    if remainder != 0 {
        returnValue = remainder <= 5 ? dimension - remainder : dimension + (10 - remainder)
    } else {
        returnValue = dimension
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
    print("     Quality: " + amount)
}


func showHelp() {
    
    // FROM 1.1.0
    // Read in app version from info.plist
    let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    
    print("\npdfmaker \(version) (\(build))")
    print("\nConvert a directory of images or a specified image to a single PDF file.\n")
    print ("Usage:\n    pdfmaker [-s <path>] [-d <path>] [-c] [-v] [-h]\n")
    print ("Options:")
    print ("    -s / --source      [path]    The path to the images or an image. Default: current folder")
    print ("    -d / --destination [path]    Where to save the new PDF. The file name is optional.")
    print ("                                 Default: ~/Desktop folder/\'PDF From Images.pdf\'.")
    print ("    -b / --break                 Break a PDF into imges.")
    print ("    -c / --compress    [amount]  Apply an image compression filter to the PDF:")
    print ("                                    0.0 = maximum compression, lowest image quality.")
    print ("                                    1.0 = no compression, best image quality.")
    print ("    -v / --verbose               Show progress information. Otherwise only errors are shown.")
    print ("    -h / --help                  This help screen.\n")
    print ("Examples:")
    print ("    pdfmaker --source ~/Documents/\'Project X\'/Images --destination ~/Documents/PDFs/\'Project X.pdf\'")
    print ("    pdfmaker --source ~/Documents/\'Project X\'/Images/cover.jpg --destination ~/Documents/PDFs\n")
}



// MARK: - Runtime Start

for argument in CommandLine.arguments {

    if argCount == 0 {
        argCount += 1
        continue
    }

    if argIsAValue {
        if argument.prefix(1) == "-" {
            print("[ERROR] Missing value for \(prevArg)")
            exit(1)
        }

        switch argType {
        case 0:
            destPath = (argument as NSString).standardizingPath
        case 1:
            sourcePath = (argument as NSString).standardizingPath
        case 2:
            outputName = argument
        case 3:
            doCompress = true
            if let cl = Float(argument) {
                compressionLevel = CGFloat(cl)
            }
        case 4:
            if let rs = Float(argument) {
                outputResolution = CGFloat(rs)
            }
        default:
            print("[ERROR] Unknown argument")
            exit(1)
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
        case "-v":
            fallthrough
        case "--verbose":
            doShowInfo = true
        case "-h":
            fallthrough
        case "--help":
            showHelp()
            exit(0)
        default:
            print("[ERROR] Unknown argument")
            exit(1)
        }

        prevArg = argument
    }

    argCount += 1
    
    // Trap commands that come last and therefore have missing args
    if argCount == CommandLine.arguments.count && argIsAValue {
        print("[ERROR] Missing value for \(argument)")
        exit(1)
    }
}

// Convert the images
var success: Bool = false
success = doBreak ? pdfToImages() : imagesToPdf()
exit(success ? 0 : 1)
