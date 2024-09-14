/*
    pdfmaker
    output-grabber.swift

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


class OutputGrabber {
    
    // Public properties
    var errors: [String] = []
    var errorCounts: [Int] = []
    var verboseErrSet: Bool = false
    
    // Private properties
    private var inputPipe: Pipe? = nil
    private var pipeReadHandle: FileHandle? = nil
    private var contents: String = ""
    
    // Constants
    private let savedStderr = dup(STDERR_FILENO)
    
    
    init() {
        // Check for the `CG_PDF_VERBOSE` env var
        // NOTE Only relevant when trapping STDERR messages from PDFKit
        if let _ = ProcessInfo.processInfo.environment["CG_PDF_VERBOSE"] {
            self.verboseErrSet = true
        }
    }
    
    
    func openConsolePipe() {
        
        // Open a new Pipe to consume the messages on STDERR.
        // We do this to catch PDFKit's irritating issuing of warnings to
        // STDERR rather than bubble up to the calling code.
        if self.inputPipe == nil {
            self.inputPipe = Pipe()
            self.pipeReadHandle = inputPipe!.fileHandleForReading
            self.pipeReadHandle!.readabilityHandler = { [weak self] fileHandle in
                guard let strongSelf = self else { return }

                let data = fileHandle.availableData
                if let string = String(data: data, encoding: String.Encoding.utf8) {
                    strongSelf.contents += string
                }
                
                let messages: [String] = strongSelf.contents.components(separatedBy: .newlines)
                if messages.count > 0 {
                    strongSelf.contents = ""
                    for message in messages {
                        if message == "" {
                            return
                        } else {
                            var doAdd: Bool = true
                            for (index, error) in strongSelf.errors.enumerated() {
                                if error == message {
                                    strongSelf.errorCounts[index] += 1
                                    doAdd = false
                                    break
                                }
                            }
                            
                            if doAdd {
                                strongSelf.errors.append(message)
                                strongSelf.errorCounts.append(1)
                            } else {
                                strongSelf.contents += message + "\n"
                            }
                        }
                    }
                }
            }
            
            // `dup2()` sets the value of the second arg to the first
            dup2(self.inputPipe!.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        }
    }


    func closeConsolePipe() -> Bool {
        
        // Restore output to STDERR
        // NOTE Docs say invalidaing `inputPipe` zaps `pipeReadHandle`.
        if self.inputPipe != nil {
            // Redirect STDERR back to tty...
            dup2(self.savedStderr, STDERR_FILENO)
            
            // ...and zap the pipe etc.
            self.contents = ""
            self.inputPipe = nil
        }
        
        return (self.errors.count > 0)
    }
}
