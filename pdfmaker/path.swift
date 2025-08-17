/*
    utitool
    path.swift

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


// MARK: - Path Processing Functions

struct Path {

    /**
     Convert a partial path to an absolute path.

     - Parameters
     - relativePath: The partial path.

     - Returns The generated absolute path.
     */
    static func getFullPath(_ relativePath: String) -> String {

        // Standardise the path as best as we can (this covers most cases)
        var absolutePath: String = (relativePath as NSString).standardizingPath

        // Check for a unresolved relative path -- and if it is one, resolve it
        // NOTE This includes raw filenames
        if (absolutePath as NSString).contains("..") || !(absolutePath as NSString).hasPrefix("/") {
            absolutePath = processRelativePath(absolutePath)
        }

        // Return the absolute path
        return absolutePath
    }


    /**
     Add the the current working directory to the supplied relative path - and then resolve it.

     - Parameters
     - relativePath: The partial path.

     - Returns The generated absolute path.
     */
    static func processRelativePath(_ relativePath: String) -> String {

        let absolutePath = FileManager.default.currentDirectoryPath + "/" + relativePath
        return (absolutePath as NSString).standardizingPath
    }


    /**
     Check if a path references a directory.

     - Parameters
     - absolutePath: An absolute path to a file or directory.

     - Returns `true` if the path references an existing directory, otherwise `false`.
     */
    static func doesPathReferenceDirectory(_ absolutePath: String) -> Bool {

        let fileURL = URL(fileURLWithPath: absolutePath)
        guard let value = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]) else { return false }
        return value.isDirectory!
    }


    /**
     Load a named file's contents into Data.

     - Parameters
     - filePath: An absolute path to a file.

     - Returns The file data, or an empty array on error.
     */
    static func getFileContents(_ filepath: String) -> ArraySlice<UInt8> {

        let fileURL: URL = URL(fileURLWithPath: filepath)
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return data.bytes[...]
    }
}


/*
 This extension property is required by the path functions.
 */
extension Data {

    // Return data as an array of bytes
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}
