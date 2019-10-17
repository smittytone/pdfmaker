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

let APP_VERSION = "1.0.0"


// MARK: - Global Variables

var argIsAValue: Bool = false
var argType: Int = -1
var argCount: Int = 0
var prevArg: String = ""
var destPath: String = "~/Desktop"
var outputName: String? = nil
var sourcePath: String = FileManager.default.currentDirectoryPath
var doCompress: Bool = false
var doShowInfo: Bool = false


// MARK: - Functions

func getFilename(_ filepath: String, _ basename: String) -> String {

    // Run through the files in the target directory and bump the
    // output file's numeric suffix so that it doesn't clash

    // Make sure we have a .pdf
    var extensionAdded: Bool = false
    if (basename as NSString).pathExtension.lowercased() == "pdf" { extensionAdded = true }

    var fullname: String = basename + (!extensionAdded ? ".pdf" : "")
    var i: Int = 0

    // Iterate through the existing files
    while FileManager.default.fileExists(atPath: (filepath + "/" + fullname)) {
        i += 1
        fullname = basename + String(format: " %02d", i) + ".pdf"
    }

    // Send back the calculated name
    return fullname
}


func imagesToPdf() -> String? {

    // Iterate through the source directory's files, adding JPEGs to the new PDF
    let destDir: String = (destPath as NSString).standardizingPath
    let srcDir: String = (sourcePath as NSString).standardizingPath
    let filename: String = getFilename(destDir, (outputName == nil ? "PDF From Images" : outputName!))
    let outputPath: String = destDir + "/" + filename

    if doShowInfo {
        print("Conversion Information")
        print("Image Source: \(srcDir)")
        print("  Target PDF: \(outputPath)")
        print("Attempting to assemble PDF file...")
    }

    var pdf: PDFDocument? = nil

    do {
        var files: [String] = try FileManager.default.contentsOfDirectory(atPath: srcDir as String)
        files.sort()
        var someFiles: Bool = false
        var fileCount: Int = 0
        var isDir: ObjCBool = true

        for i in 0..<files.count {
            let file: String = srcDir + "/" + files[i]
            _ = FileManager.default.fileExists(atPath: file, isDirectory: &isDir)
            if !isDir.boolValue {
                let ext: String = (file as NSString).pathExtension.lowercased()

                if doShowInfo {
                    let extra: String = ext.count == 0 ? "ignoring" : "processing"
                    print("Found file: \(file)... \(extra)")
                }

                if ext == "jpg" || ext == "jpeg" {
                    someFiles = true
                    let image: NSImage? = NSImage.init(contentsOfFile: file)
                    if image != nil {
                        let page: PDFPage? = PDFPage.init(image: image!)
                        if page != nil {
                            if fileCount == 0 {
                                if let pageData: Data = page!.dataRepresentation {
                                    pdf = PDFDocument.init(data: pageData)
                                    fileCount += 1
                                }
                            } else {
                                if let newpdf: PDFDocument = pdf {
                                    newpdf.insert(page!, at: fileCount)
                                    fileCount += 1
                                }
                            }
                        }
                    } else {
                        print("[ERROR] Could not load image for file \(file)")
                    }
                }
            }
        }

        if someFiles {
            if let newpdf: PDFDocument = pdf {
                if doShowInfo { print("Writing PDF file \(outputPath)") }
                newpdf.write(toFile: outputPath)
                return outputPath
            }
        }
    } catch {
        print("[ERROR] Unable to get contents of directory")
    }

    return nil
}


func compressPdfImages(_ inputPath: String) {

    // Compress the images with the specified PDF file using Quartz filter
    if doShowInfo { print("Attempting to compress \(inputPath)...") }

    // Get the full path to 'PDFer.qfilter'
    var filterPath: String = "~/Library/Filters/PDFer.qfilter"
    filterPath = (filterPath as NSString).standardizingPath

    // Set the output name
    let outputDir: String = (inputPath as NSString).deletingLastPathComponent
    let outputName: String = (inputPath as NSString).lastPathComponent
    let outputNameParts: [String] = outputName.components(separatedBy: ".")
    let outputPath: String = outputDir + "/" + outputNameParts[0] + ".compressed.pdf"

    // Create URLs from the string paths:
    // First the filer...
    let filterURL: URL = URL.init(fileURLWithPath: filterPath)
    let srcURL: URL = URL.init(fileURLWithPath: inputPath)

    // Load in the PDF we have just made
    if let compressedPdf: PDFDocument = PDFDocument.init(url: srcURL) {
        // Load and apply the filter
        let filter: QuartzFilter = QuartzFilter.init(url: filterURL)

        if let pdfData: Data = compressedPdf.dataRepresentation(options: [AnyHashable("QuartzFilter"):filter])
        {
            do {
                try pdfData.write(to: URL.init(fileURLWithPath: outputPath))

                //compressedPdf.write(toFile: outputPath, withOptions: [kCGPDFContextAllowsPrinting:filter])
            } catch {
                print("[ERROR] Could not write the compressed PDF file")
            }
        } else {
            print("[ERROR] Could not apply the compressed filter")
        }
    } else {
        print("[ERROR] Could not load the new PDF file for compression")
    }
}


func showHelp() {

    print("\npdfmaker \(APP_VERSION)")
    print("\nConvert a directory of images to a single PDF file.\n")
    print ("Usage:\n    pdfmaker [-s <directory path>] [-d <directory path>] [-n <name>] [-c] [-h]\n")
    print ("Options:")
    print ("    -s / --source      [path]   The path to the images. Default: current folder")
    print ("    -d / --destination [path]   Where to save the PDF. Default: Desktop folder.")
    print ("    -n / --name        [name]   The name of the new PDF. Default: \'PDF From Images\'.")
    print ("    -c / --compress             Apply an image compression filter to the PDF.")
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
            doCompress = true
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

    if argCount == CommandLine.arguments.count && argIsAValue {
        print("*[ERROR] Missing value for \(argument)")
        exit(1)
    }
}

// Convert the images and, if required, compress the PDF
let outputFile: String? = imagesToPdf()
if outputFile != nil && doCompress { compressPdfImages(outputFile!) }
