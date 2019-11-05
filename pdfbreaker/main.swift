//
//  main.swift
//  pdfbreaker
//
//  Created by Tony Smith on 31/10/2019.
//  Copyright © 2019 Tony Smith. All rights reserved.
//

import Foundation
import Quartz


// MARK: - Global Variables

var argIsAValue: Bool = false
var argType: Int = -1
var argCount: Int = 0
var prevArg: String = ""
var destPath: String = "~/Desktop"
var outputName: String? = nil
var sourcePath: String = FileManager.default.currentDirectoryPath
var doCompress: Bool = false
var compressionLevel: Float = 0.8
var doShowInfo: Bool = false


// MARK: - Functions

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


func pdfToImages() {

    // Iterate through the source directory's files, or the named source file, adding
    // any JPEGs we find to the new PDF
    
    // Expand the source and destination directories to full paths
    var destDir: String = (destPath as NSString).standardizingPath
    let srcDir: String = (sourcePath as NSString).standardizingPath
    
    // Check the supplied directories
    // NOTE 'checkDirectory()' will exit if the either item doesn't exist
    let isSrcADir: Bool = checkDirectory(srcDir, "Source")
    let isDestADir: Bool = checkDirectory(destDir, "Target")
    var filename: String
    
    // Determine the destination filename
    if isDestADir {
        // Destination path indicates a directory, so prepare the filename
        filename = getFilename(destDir, (outputName == nil ? "PDF From Images" : outputName!))
    } else {
        // Destination path indicates a file, so extract the filename
        // NOTE The file may not exist at this point -- we will make it later.
        filename = (destDir as NSString).lastPathComponent
        destDir = (destDir as NSString).deletingLastPathComponent
        filename = getFilename(destDir, filename)
    }
    
    // Set the destination path from the generated filename
    let savePath: String = destDir + "/" + filename
    
    if doShowInfo {
        // We're in verbose mode, so show some info
        print("Conversion Information")
        print("Image Source: \(srcDir)")
        print("  Target PDF: \(savePath)")
        if doCompress {
            let percent: Int = Int(compressionLevel * 100)
            var amount = "\(percent)%"
            if percent == 0 { amount = "Least (" + amount + ")" }
            if percent == 100 { amount = "Maxiumum (" + amount + ")" }
            if doShowInfo { print("     Quality: " + amount) }
        }
        print("Attempting to assemble PDF file...")
    }

    var files: [String]

    if isSrcADir {
        // We have a directory of files, so load a list of items into 'files'
        do {
            // Get a list of files in the source directory and sort them so that they get added
            // to the output PDF in the correct order
            files = try FileManager.default.contentsOfDirectory(atPath: srcDir)
            files.sort()
        } catch {
            // NOTE This should not be triggered due to earlier checks
            print("[ERROR] Unable to get contents of directory")
            return
        }
    } else {
        // 'srcDir' points to a file, so add it to files array manually
        files = [srcDir]
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
            file = srcDir + "/" + files[i]
        } else {
            file = files[i]
        }

        // Get the file extension
        let ext: String = (file as NSString).pathExtension.lowercased()

        if doShowInfo {
            let extra: String = ext.count == 0 ? "ignoring" : "processing"
            print("Found file: \(file)... \(extra)")
        }

        // Only proceed if the file is a PDF
        if ext == "pdf" {
            gotFirstImage = true
            
            // Load the PDF
            do {
                let fileData: Data = try Data.init(contentsOf: URL.init(fileURLWithPath: file))
                if let pdf: PDFDocument = PDFDocument.init(data: fileData) {
                    for i in 0..<pdf.pageCount {
                        if let page: PDFPage = pdf.page(at: i) {
                            if let cs: CGColorSpace = CGColorSpace.init(name: CGColorSpace.sRGB) {
                                if let context: CGContext = CGContext.init(data: nil,
                                                                           width: 1666,
                                                                           height: 2224,
                                                                           bitsPerComponent: 8,
                                                                           bytesPerRow: 0,
                                                                           space: cs,
                                                                           bitmapInfo: 0) {
                                    page.draw(with: .cropBox, to: context)
                                    if let cimage: CGImage = context.makeImage() {
                                        let image: NSImage = NSImage.init(cgImage: cimage, size: page.bounds(for: .cropBox).size)
                                        // if doCompress { image = compressImage(image) }
                                        // Write the file
                                        var imageData: Data? = image.tiffRepresentation
                                        if imageData != nil {
                                            if let imageRep: NSBitmapImageRep = NSBitmapImageRep.init(data: imageData!) {
                                                let imageProps: [NSBitmapImageRep.PropertyKey: Any] = [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0]
                                                imageData = imageRep.representation(using: .jpeg, properties: imageProps)
                                                let path: String = destDir + "/page " + String(format: "%03d", i) + ".jpg"
                                                try imageData!.write(to: URL.init(fileURLWithPath: path))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                print("[ERROR] Could not load image for file \(file)")
            }
        }
    }

    // Did we add any images to the PDF?
    if !gotFirstImage && doShowInfo {
        print("No suitable image files found in the source directory")
    }
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
            destPath = argument
        case 1:
            sourcePath = argument
        case 2:
            outputName = argument
        case 3:
            doCompress = true
            if let cl = Float(argument) {
                compressionLevel = cl
            } else {
                compressionLevel = 0.8
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
pdfToImages()

