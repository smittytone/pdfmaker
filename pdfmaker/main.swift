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
import Clicore


// MARK: Constants

// FROM 2.0.0
let BASE_DPI: CGFloat    = 72.0
let DEFAULT_DPI: CGFloat = 300.0


// MARK: Global Variables

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
// FROM 2.4.0
var breakToText: Bool = false
var hasSetRes: Bool = false


// MARK: Runtime Start

// FROM 2.3.2
// Make sure the signal does not terminate the application
Stdio.enableCtrlHandler("pdfmaker interrupted -- halting")

// FROM 2.3.0
// No arguments? Show Help
if CommandLine.arguments.count == 1 {
    showHelp()
    Stdio.disableCtrlHandler()
    exit(EXIT_SUCCESS)
}

// Expand composite flags
var args: [String] = Cli.unify(args: CommandLine.arguments)

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
            Stdio.reportErrorAndExit("Missing value for \(prevArg)")
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
                Stdio.reportErrorAndExit("Compression level out of range")
            }
        case 4:
            if let rs = Float(argument) {
                outputResolution = CGFloat(rs)
                hasSetRes = true
            }

            // FROM 2.3.0 -- check values!
            if outputResolution < 1 || outputResolution > 9999 {
                Stdio.reportErrorAndExit("Output resolution out of range")
            }
        default:
                Stdio.reportErrorAndExit("Unknown argument: \(argument)")
        }

        argIsAValue = false
    } else {
        switch argument {
        case "-d", "--destination":
            argType = 0
            argIsAValue = true
        case "-s", "--source":
            argType = 1
            argIsAValue = true
        case "-n", "--name":
            argType = 2
            argIsAValue = true
        case "-c", "--compress":
            argType = 3
            argIsAValue = true
        case "-r", "--resolution":
            argType = 4
            argIsAValue = true
        case "-b", "--break":
            doBreak = true
        case "-t", "--text":
            breakToText = true
        case "--createdirs":
            doMakeSubDirectories = true
        case "-v", "--verbose":
            doShowInfo = true
        case "-h", "--help":
            showHelp()
            Stdio.disableCtrlHandler()
            exit(EXIT_SUCCESS)
        case "--version":
            showHeader()
            Stdio.disableCtrlHandler()
            exit(EXIT_SUCCESS)
        default:
            Stdio.reportErrorAndExit("Unknown argument: \(argument)")
        }

        prevArg = argument
    }

    argCount += 1

    // Trap commands that come last and therefore have missing args
    if argCount == CommandLine.arguments.count && argIsAValue {
        Stdio.reportErrorAndExit("Missing value for \(argument)")
    }
}

// FROM 2.4.8
if !doBreak {
    if breakToText {
        reportUnnecessary(option: "-t/--text")
    }
} else {
    if doCompress {
        reportUnnecessary(option: "-c/--compress")
    }

    if hasSetRes {
        reportUnnecessary(option: "-r/--resolution")
    }
}

// FROM 2.3.0
// Fix source and destination paths here, not if they were set
// (so we catch the defaults)
destPath = Path.getFullPath(destPath)
sourcePath = Path.getFullPath(sourcePath)

// Check the supplied paths
// NOTE 'checkDirectory()' will exit if the either item doesn't exist
let isSrcADir: Bool = Pdf.checkDirectory(sourcePath, "Source")
let isDestADir: Bool = Pdf.checkDirectory(destPath, "Target")

// Process files
// FROM 2.4.0 support output to text
var success: Bool
if doBreak {
    success = breakToText ? Pdf.pdfToText(isSrcADir, isDestADir) : Pdf.pdfToImages(isSrcADir, isDestADir)
} else {
    success = Pdf.imagesToPdf(isSrcADir, isDestADir)
}
Stdio.disableCtrlHandler()
exit(success ? EXIT_SUCCESS : EXIT_FAILURE)


// MARK: Utility Functions

/**
 Generic warning handler for flags included but irrelevant to requested action.

 FROM 2.4.0

 - Parameters:
    - option The unneceesary flag, eg. `--compress`
 */
func reportUnnecessary(option: String) {

    Stdio.reportWarning("\(option) flag is not relevant -- ignoring")
}


// MARK: Help and Info Functions

/**
 Display the help screen.
 */
func showHelp() {

    showHeader()

    Stdio.report("\nConvert a directory of images or a specified image to a single PDF file, or")
    Stdio.report("expand a single PDF file into a collection of image files.\n")
    Stdio.report("\(String(.bold))USAGE\(String(.normal))\n    pdfmaker [-s path] [-d path] [-c value] [-r value] [-b ] [-v] [-h]\n")
    Stdio.report("\(String(.bold))OPTIONS\(String(.normal))")
    Stdio.report("    -s | --source      {path}    The path to the images or an image. Default: current folder")
    Stdio.report("    -d | --destination {path}    Where to save the new PDF. The file name is optional.")
    Stdio.report("                                 Default: ~/Desktop folder/\'PDF From Images.pdf\'.")
    Stdio.report("    -n | --name        {name}    Specify the target file name. Only used when your destination")
    Stdio.report("                                 is a directory.")
    Stdio.report("    -c | --compress    {amount}  Apply an image compression filter to the PDF:")
    Stdio.report("                                 0.0 = maximum compression, lowest image quality.")
    Stdio.report("                                 1.0 = no compression, best image quality.")
    Stdio.report("         --createdirs            Make target intermediate directories if they do not exist.")
    Stdio.report("    -b | --break                 Break a PDF into JPEG images unless the --text flag is set.")
    Stdio.report("    -r | --resolution  {dpi}     The output resolution of extracted images. Max: 9999.")
    Stdio.report("    -t | --text                  Extract the source’s text and don’t generate images.")
    Stdio.report("    -v | --verbose               Show progress information. Otherwise only errors are shown.")
    Stdio.report("    -h | --help                  This help screen.")
    Stdio.report("         --version               Show pdfmaker version information.\n")
    Stdio.report("\(String(.bold))EXAMPLES\(String(.normal))")
    Stdio.report("    pdfmaker --source $IMAGES_DIR --destination $PDFS_DIR/\'Project X.pdf\' --compress 0.8")
    Stdio.report("    pdfmaker --source $IMAGES_DIR/cover.jpg --destination $PDFS_DIR --compress 0.5")
    Stdio.report("    pdfmaker --break --source $PDFS_DIR/\'Project X.pdf\' --destination $IMAGES_DIR")
    Stdio.report("    pdfmaker --break --text --source $PDFS_DIR/\'Project X.pdf\' --destination \"$HOME/report.txt\"\n")
    Stdio.report("\(String(.italic))https://github.com/smittytone/pdfmaker\(String(.normal))")
}


/**
 Display the app's version and other information.

 FROM 2.1.0
 */
func showHeader() {

    let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    let name:String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    Stdio.report("\(String(.bold))\(name) \(version) (\(build))\(String(.normal))")
    Stdio.report("Copyright © 2025, Tony Smith (@smittytone). Source code available under the MIT licence.")
}
