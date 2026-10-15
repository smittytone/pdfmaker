//
//  utilities.swift
//  pdfmaker
//
//  Created by Tony Smith on 15/10/2026.
//  Copyright © 2026 Tony Smith. All rights reserved.
//

import AppKit
import Quartz
import Clicore


extension Pdfmaker {

    /**
     Run through the files in the specified directory and set the output
     file's name so that it doesn't clash with existing files. For example,
     if `Untitled.pdf` exists, this will generate `Untitled 01.pdf`

     - Parameters:
        - filepath The directory's path.
        - basename The base output filename to which integers will be appended.

     - Returns: The new file name, or the existing one if it's OK.
     */
    internal static func getFilename(_ directory: URL, _ basename: String) -> String {

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
        while FileManager.default.fileExists(atPath: (directory.path + "/" + newFilename)) {
            // The named file exists, so add a numeric suffix to the filename and re-check
            i += 1
            newFilename = newBasename + String(format: " %02d", i) + ".pdf"
        }

        // FROM 2.0.1
        // Bail if the filename exceeds 255 UTF-8 characters
        // TODO Make this more intelligent: truncate the file name?
        if newFilename.count > 255 {
            Stdio.reportErrorAndExit("Generated filename \(newFilename) is too long -- please provide a shorter filename")
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
                a non-existent file, or a non-existent directory that can't be created.
     */
    internal static func check(directory: URL, _ type: DirectoryType, _ doMakeSubDirectories: Bool) -> FileCheckResult {

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDir) {
            // The path points to an existing item, so return its type
            return isDir.boolValue ? .existingDirectory : .existingFile
        }

        // Does the non-existent item specify a file, ie. does it have an extension?
        let ext = directory.pathExtension
        if ext.count > 0 {
            // There is an extension, so assume it points to a file,
            // which we will create later
            return .nonFile
        }

        // FROM 2.3.0
        // Try and make intermediate directories if we can and are asked to
        if doMakeSubDirectories {
            do {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: directory.path),
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            } catch {
                Stdio.reportErrorAndExit("\(type.rawValue) directory \(directory.path) does not exist and cannot be created")
            }
        } else {
            Stdio.reportErrorAndExit("\(type.rawValue) directory \(directory.path) does not exist. Use the --createdirs switch")
        }

        return .existingDirectory
    }


    /**
     Display the chosen image compression level.
     */
    internal static func reportCompressionLevel(_ compressionLevel: CGFloat) {

        let percent = Int(compressionLevel * 100)
        var amount = "\(percent)%"
        if percent == 0 { amount = "Least (" + amount + ")" }
        if percent == 100 { amount = "Maxiumum (" + amount + ")" }
        Stdio.report("     Quality: " + amount)
    }


    /**
     Report information, if requested by the user.
     */
    internal static func reportInfo(_ message: String) {

        Stdio.report(withEmoji: "✅", message)
    }

}
