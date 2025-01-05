/*
    pdfmaker
    output-grabber.swift

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


class OutputGrabber {
    
    // MARK: -  Public properties
    var errors: [String] = []
    var errorCounts: [Int] = []
    var verboseErrSet: Bool = false
    
    
    // MARK: -  Private properties
    private var inputPipe: Pipe? = nil
    private var pipeReadHandle: FileHandle? = nil
    private var contents: String = ""
    private var doDeDupe: Bool = false
    
    
    // MARK: -  Constants
    private let savedStderr = dup(STDERR_FILENO)
    
    
    
    // MARK: - Methods: Instance Lifecyle
    
    init(dedupe: Bool = false) {
        // Check for the `CG_PDF_VERBOSE` env var
        // NOTE Only relevant when trapping STDERR messages from PDFKit
        //      within my pdfmaker app -- you probably will not require this.
        if let _ = ProcessInfo.processInfo.environment["CG_PDF_VERBOSE"] {
            self.verboseErrSet = true
        }
        
        // Record whether the user wants to de-dupe incomimg messages
        self.doDeDupe = dedupe
    }
    
    
    // MARK: -  Methods: Pipe Management
    
    ///
    /// Open a new Pipe to consume the messages on `STDERR`.
    ///
    func openConsolePipe() {
        
        if self.inputPipe == nil {
            self.inputPipe = Pipe()
            self.pipeReadHandle = inputPipe!.fileHandleForReading
            self.pipeReadHandle!.readabilityHandler = { [weak self] fileHandle in
                // NOTE Pass in `weak self` to avoid reference cycle to `self`.
                //      Hence the following check: bail if the instance reference
                //      is `nil`.
                guard let strongSelf = self else { return }

                // If there's available output to the redirected file handle,
                // get it and store it for processing later
                let data = fileHandle.availableData
                if let string = String(data: data, encoding: String.Encoding.utf8) {
                    strongSelf.contents += string
                }
                
                if strongSelf.doDeDupe {
                    // Separate out the received messages and de dupe
                    let messages: [String] = strongSelf.contents.components(separatedBy: .newlines)
                    if messages.count > 0 {
                        strongSelf.contents = ""
                        for message in messages {
                            if message == "" {
                                return
                            } else {
                                // Have we got the received message? Assume we don't
                                var doAdd: Bool = true
                                for (index, error) in strongSelf.errors.enumerated() {
                                    if error == message {
                                        strongSelf.errorCounts[index] += 1
                                        doAdd = false
                                        break
                                    }
                                }
                                
                                if doAdd {
                                    // Record the new message
                                    strongSelf.errors.append(message)
                                    strongSelf.errorCounts.append(1)
                                } else {
                                    // Put the duplicate message back into the buffer
                                    // TODO Is this really beneficial?
                                    strongSelf.contents += message + "\n"
                                }
                            }
                        }
                    }
                }
            }
            
            // `dup2()` sets the value of the second arg to the first
            dup2(self.inputPipe!.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        }
    }
    
    
    ///
    /// Restore output to `STDERR`.
    ///
    /// Returns: `true` on success, otherwise `false`.
    ///
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
