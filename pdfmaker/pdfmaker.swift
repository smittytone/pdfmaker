/*
    pdfmaker
    pdfmaker.swift

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


@main
struct Pdfmaker {

    public static func main() async throws {

        // FROM 2.3.2
        // Make sure the signal does not terminate the application
        Stdio.enableCtrlHandler("pdfmaker interrupted -- halting")
        Stdio.settings.useEmoji = true

        // FROM 2.3.0
        // No arguments? Show Help
        if CommandLine.arguments.count == 1 {
            showHelp()
            Stdio.exitApp()
        }

        // Run settings and preferencess
        var settings = Settings()

        // Expand composite flags
        let arguments = Cli.unify(args: CommandLine.arguments)
        var argumentIsAValue = false
        var argumentType: ArgumentID = .unknown
        var argumentCount = 0
        var previousArgument = ""

        // Process the (separated) arguments
        for argument in arguments {
            if argumentType != .unknown {
                // Make sure we're not reading in an option rather than a value
                if argument.prefix(1) == "-" {
                    Stdio.reportErrorAndExit("Missing value for \(previousArgument)")
                }

                switch argumentType {
                    case .pathDestination:
                        settings.destPath = argument
                    case .pathSource:
                        settings.sourcePath = argument
                    case .nameTarget:
                        settings.outputName = argument
                    case .compressionLevel:
                        settings.doCompress = true
                        if let cl = Float(argument) {
                            if cl < 0.0 || cl > 1.0 {
                                Stdio.reportErrorAndExit("Compression level out of range")
                            }

                            settings.compressionLevel = CGFloat(cl)
                        }
                    case .resolution:
                        if let rs = Float(argument) {
                            if rs < 1.0 || rs > 9999.0 {
                                Stdio.reportErrorAndExit("Output resolution out of range")
                            }

                            settings.outputResolution = CGFloat(rs)
                            settings.hasSetRes = true
                        }
                    case .metadataTitle:
                        settings.metadata.title = argument
                    case .metadataSubject:
                        settings.metadata.subject = argument
                    case .metadataAuthor:
                        settings.metadata.author = argument
                    case .metadataAdmin:
                        settings.metadata.password = argument
                    default:
                        Stdio.reportErrorAndExit("Unknown argument: \(argument)")
                }

                argumentType = .unknown
                argumentIsAValue = false
            } else {
                switch argument {
                    case "-d", "--destination":
                        argumentType = .pathDestination
                        argumentIsAValue = true
                    case "-s", "--source":
                        argumentType = .pathSource
                        argumentIsAValue = true
                    case "-n", "--name":
                        argumentType = .nameTarget
                        argumentIsAValue = true
                    case "-c", "--compress":
                        argumentType = .compressionLevel
                        argumentIsAValue = true
                    case "-r", "--resolution":
                        argumentType = .resolution
                        argumentIsAValue = true
                    case "-b", "--break":
                        settings.doBreak = true
                    case "-t", "--text":
                        settings.breakToText = true
                    case "--createdirs":
                        settings.doMakeSubDirectories = true
                    case "-v", "--verbose":
                        settings.doShowInfo = true
                    case "--title":
                        argumentIsAValue = true
                        argumentType = .metadataTitle
                    case "--subject":
                        argumentIsAValue = true
                        argumentType = .metadataSubject
                    case "--author":
                        argumentIsAValue = true
                        argumentType = .metadataAuthor
                    case "--password":
                        argumentIsAValue = true
                        argumentType = .metadataAdmin
                    case "-h", "--help":
                        showHelp()
                        Stdio.exitApp()
                    case "--version":
                        showHeader()
                        Stdio.exitApp()
                    default:
                        Stdio.reportErrorAndExit("Unknown argument: \(argument)")
                }

                previousArgument = argument
            }

            argumentCount += 1

            // Trap commands that come last and therefore have missing args
            if argumentCount == arguments.count && argumentIsAValue {
                Stdio.reportErrorAndExit("Missing value for \(argument)")
            }
        }

        // FROM 2.4.8
        if settings.doBreak {
            if settings.doCompress {
                reportUnnecessary(option: "-c/--compress")
            }

            if settings.breakToText && settings.hasSetRes {
                reportUnnecessary(option: "-r/--resolution")
            }
        } else {
            if settings.breakToText {
                reportUnnecessary(option: "-t/--text")
            }

            if settings.hasSetRes {
                reportUnnecessary(option: "-r/--resolution")
            }
        }

        // FROM 2.3.0
        // Fix source and destination paths here, not if they were set
        // (so we catch the defaults)
        settings.destPath = Path.getFullPath(settings.destPath)
        settings.destination = URL(fileURLWithPath: settings.destPath)
        settings.sourcePath = Path.getFullPath(settings.sourcePath)
        settings.source = URL(fileURLWithPath: settings.sourcePath)

        // Check the supplied paths
        settings.sourceIsDir = check(directory: settings.source, .source, settings.doMakeSubDirectories) == .existingDirectory
        settings.destIsDir = check(directory: settings.destination, .target, settings.doMakeSubDirectories) == .existingDirectory

        // Process files
        // FROM 2.4.0 support output to text
        var outcome = EXIT_FAILURE
        let result: Result<Bool, ProcessError>
        if settings.doBreak {
            result = settings.breakToText ? pdfToText(settings) : pdfToImages(settings)
        } else {
            result = imagesToPdf(settings)
        }

        switch result {
            case .failure(let error):
                Stdio.reportError(error.localizedDescription)
            case .success(_):
                outcome = EXIT_SUCCESS
        }

        Stdio.exitApp(outcome)
    }


    // MARK: Utility Functions

    /**
     Generic warning handler for flags included but irrelevant to requested action.

     FROM 2.4.0

     - Parameters:
     - option The unneceesary flag, eg. `--compress`
     */
    internal static func reportUnnecessary(option: String) {

        Stdio.reportWarning("\(option) flag is not relevant -- ignoring")
    }

}
