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

let APP_VERSION = "1.1.0"


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

    // Run through the files in the target directory and bump the
    // output file's numeric suffix so that it doesn't clash

    // Add '.pdf' to the filename if it's not there already
    var extensionAdded: Bool = false
    if (basename as NSString).pathExtension.lowercased() == "pdf" { extensionAdded = true }
    
    var fullname: String = basename + (!extensionAdded ? ".pdf" : "")
    var i: Int = 0

    // Iterate through the existing files
    while FileManager.default.fileExists(atPath: (filepath + "/" + fullname)) {
        // The named file exists, so add a numeric suffix to the filename and re-check
        i += 1
        fullname = basename + String(format: " %02d", i) + ".pdf"
    }

    // Send back the derived name
    return fullname
}


func checkDirectory(_ dir: String, _ dirType: String) -> Bool {
    
    // Make sure the specified directory ('dir') and is indeed a directory,
    // bailing if it’s missing or a regular file.
    // The 'dirType' parameter is passed into the error report, if issued
    
    var isDir: ObjCBool = true
    let success: Bool = FileManager.default.fileExists(atPath: dir, isDirectory: &isDir)

    if !success {
        // Item doesn't exist, whatever it is
        print("[ERROR] \(dirType) directory \(dir) does not exist")
        exit(1)
    }

    // FROM 1.1.0
    // Return a bool indicating whether path points to a director (true) or a file (false)
    return isDir.boolValue
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


func imagesToPdf() -> String? {

    // Iterate through the source directory's files, adding JPEGs to the new PDF
    
    // Expand the directories to full pasth
    let destDir: String = (destPath as NSString).standardizingPath
    let srcDir: String = (sourcePath as NSString).standardizingPath
    let filename: String = getFilename(destDir, (outputName == nil ? "PDF From Images" : outputName!))
    let outputPath: String = destDir + "/" + filename
    
    // Check the supplied directories
    let isDir: Bool = checkDirectory(srcDir, "Source")
    let _ = checkDirectory(destDir, "Target")
    
    if doShowInfo {
        // We're in verbose mode, so show some info
        print("Conversion Information")
        print("Image Source: \(srcDir)")
        print("  Target PDF: \(outputPath)")
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

    if isDir {
        // We have a directory of files, so load a list of items into 'files'
        do {
            // Get a list of files in the source directory and sort them so that they get added
            // to the output PDF in the correct order
            files = try FileManager.default.contentsOfDirectory(atPath: srcDir as String)
            files.sort()
        } catch {
            // NOTE This should not be triggered due to earlier checks
            print("[ERROR] Unable to get contents of directory")
            return nil
        }
    } else {
        // 'srcDir' points to a file, so add it to files manually
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
        if isDir {
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
            if doShowInfo { print("Writing PDF file \(outputPath)") }
            newpdf.write(toFile: outputPath)
            return outputPath
        }
    } else {
        if doShowInfo {
            print("No suitable image files found in the source directory")
        }
    }

    return nil
}


func showHelp() {

    print("\npdfmaker \(APP_VERSION)")
    print("\nConvert a directory of images or a specified image to a single PDF file.\n")
    print ("Usage:\n    pdfmaker [-s <directory path>] [-d <directory path>] [-n <name>] [-c] [-h]\n")
    print ("Options:")
    print ("    -s / --source      [path]   The path to the image(s). Default: current folder")
    print ("    -d / --destination [path]   Where to save the PDF. Default: Desktop folder.")
    print ("    -n / --name        [name]   The name of the new PDF. Default: \'PDF From Images\'.")
    print ("    -c / --compress    [amount] Apply an image compression filter to the PDF.")
    print ("    -v / --verbose              Show progress information. Otherwise only errors are shown.")
    print ("    -h / --help                 This help screen.\n")
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
        print("*[ERROR] Missing value for \(argument)")
        exit(1)
    }
}

// Convert the images
let outputFile: String? = imagesToPdf()
