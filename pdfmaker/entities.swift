/*
    pdfmaker
    entities.swift

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


/*
    A simple structure to record PDF document metadata provided to the app
    at the command line.
 */
internal struct Metadata {

    var title: String       = ""
    var subject: String     = ""
    var author: String      = ""
    var password: String    = ""
}


/*
 A basic structure to record text lines and their PDF geometry during
 text extraction routines.
 */
internal struct PdfLine {

    let text: String
    let bounds: CGRect
    let page: Int
    let line: Int
}


/*
    Allowed argument types
 */
enum ArgumentID {

    case pathDestination
    case pathSource
    case nameTarget
    case compressionLevel
    case resolution
    case metadataTitle
    case metadataSubject
    case metadataAuthor
    case metadataAdmin
    case unknown
}


enum DirectoryType: String {

    case source = "Source"
    case target = "Target"
}


enum FileCheckResult {

    case existingFile
    case existingDirectory
    case nonFile
    case nonDirectory

}


struct Settings {

    var doCompress: Bool                = false
    var doShowInfo: Bool                = false
    var doBreak: Bool                   = false
    var doMakeSubDirectories: Bool      = false
    var isPiped: Bool                   = false
    var breakToText: Bool               = false
    var hasSetRes: Bool                 = false
    var sourceIsDir: Bool                 = true  // DEP
    var destIsDir: Bool                = true  // DEP
    var outputResolution: CGFloat       = BASE_DPI
    var compressionLevel: CGFloat       = 0.8
    var destPath: String                = "~/Desktop"   // DEP
    var sourcePath: String              = FileManager.default.currentDirectoryPath  // DEP
    var outputName: String?             = nil
    let grabber: OutputGrabber          = OutputGrabber(dedupe: true)
    var metadata: Metadata              = Metadata()

    var destination: URL                = FileManager.default.homeDirectoryForCurrentUser.appendingPathExtension("Desktop")
    var source: URL                     = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}


public struct ProcessError: Error, LocalizedError {

    public var code: ProcessErrorKind                  = .noError
    public var text: String?                           = nil
    public var errorDescription: String? {
        switch self.code {
            case .noError:
                return nil
            case .badPdfWrite:
                guard let text = self.text else { return "Error message not provided" }
                return "could not write PDF file \(text)"
            default:
                guard let text = self.text else { return "Error message not provided" }
                return text
        }
    }
}


/*
    Word file processing error codes.
    NOTE We require raw values for these, for output as stderr codes.
*/
public enum ProcessErrorKind: Int, Error {

    case noError
    case badPdfExtract
    case badPdfWrite
    case badPdfFile
    case badtextWrite
    case badDirLoad
    case badFileLoad
    case destNotDir
    case sourceIsDir
    case sourceNotPdf
}
