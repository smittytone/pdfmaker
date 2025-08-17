/*
    utitool
    stdio.swift

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


/*
 Base STDIO library for use in my CLI applications.

 Data values are a mix of enums and structs, accessed via the `Stdio` namespace.

 Functions are static and so are likewised accessed via the `Stdio` namespace.
 */
struct Stdio {

    /*
     The customary 8-bit shell colours.
     */
    enum ShellColour: Int {

        case black              // 0
        case red                // 1
        case green              // 2
        case yellow             // 3
        case blue               // 4
        case magenta            // 5
        case cyan               // 6
        case white              // 7
        case undefined          // 8
        case `default`          // 9


        /**
         Get the value as a foreground colour string.
         */
        func foreground() -> String {

            return tostring(baseValue: 30)
        }


        /**
         Get the value as a background colour string.
         */
        func background() -> String {

            return tostring(baseValue: 40)

        }


        /**
         Convert the enum to a suitable string for issuing via STDIO.
         */
        private func tostring(baseValue: Int) -> String {

            let value = self.rawValue + baseValue
            return "\u{001B}[\(value)m"
        }
    }


    /*
     The customary shell display styles.
     */
    enum ShellStyle: Int {

        case normal             // 0
        case bold               // 1
        case dim                // 2
        case italic             // 3
        case underline          // 4
        case blinking           // 5
        case undefined          // 6
        case inverse            // 7
        case hidden             // 8
        case strikethrough      // 9


        /**
         Get the value of the style's enable action as a string.
         */
        func on() -> String {

            return tostring(baseValue: 0)
        }


        /**
         Get the value of the style's disable action as a string.
         */
        func off() -> String {

            return tostring(baseValue: 20)

        }


        /**
         Convert the enum to a suitable string for issuing via STDIO.
         */
        private func tostring(baseValue: Int) -> String {

            let value = self.rawValue + baseValue
            return "\u{001B}[\(value)m"
        }
    }


    struct ShellRoutes {

        static let Error: FileHandle    = FileHandle.standardError
        static let Output: FileHandle   = FileHandle.standardOutput
    }


    struct ShellCursor {

        private enum Direction: String {
            case up         = "A"
            case down       = "B"
            case `left`     = "C"
            case `right`    = "D"
            case next       = "E"
            case previous   = "F"
            case column     = "G"
        }


        static let Backspace: String    = String(UnicodeScalar(8))
        static let Newline: String      = String(UnicodeScalar(10))
        static let Return: String       = String(UnicodeScalar(13))
        static let Clearline: String    = "\u{001B}[2K"
        static let Home: String         = "\u{001B}[H"


        func up(lines: Int) -> String {

            return moveCursor(lines, .up)
        }


        func down(lines: Int) -> String {

            return moveCursor(lines, .down)
        }


        func left(columns: Int) -> String {

            return moveCursor(columns, .left)
        }


        func right(columns: Int) -> String {

            return moveCursor(columns, .right)
        }


        func toColumn(_ column: Int) -> String {

            var amount = column
            if amount < 0 {
                amount = 0
            }

            return "\u{001B}[\(amount)\(Direction.column.rawValue)"
        }


        func back(lines: Int) -> String {

            return moveCursor(lines, .previous)
        }


        func forward(lines: Int) -> String {

            return moveCursor(lines, .next)
        }


        private func moveCursor(_ steps: Int, _ direction: Direction) -> String {

            if steps < 1 {
                return ""
            }

            return "\u{001B}[\(steps)\(direction.rawValue)"
        }
    }


    // MARK: Public Properties

    static var dispatchSource: DispatchSourceSignal? = nil


    // MARK: Public Functions for Reporting and Data Output

    /**
     Generic message display routine.
     */
    static func report(_ message: String) {

        writeToStderr(message)
    }


    /**
     Generic warning display routine.
     */
    static func reportWarning(_ message: String) {

        writeToStderr(String(.yellow) + String(.bold) + "WARNING " + String(.normal) + message)
    }


    /**
     Generic error display routine, but do not exit.
     */
    static func reportError(_ message: String) {

        writeToStderr(String(.red) + String(.bold) + "ERROR " + String(.normal) + message)
    }


    /**
     Generic error display routine, exiting the app after displaying the message.
     */
    static func reportErrorAndExit(_ message: String, _ code: Int32 = EXIT_FAILURE) {

        writeToStderr(String(.red) + String(.bold) + "ERROR " + String(.normal) + message + " -- exiting")
        dispatchSource?.cancel()
        exit(code)
    }


    /**
     Generic data output routine.
     */
    static func output(_ data: String) {

        writeToStdout(data)
    }


    /**
     Write a message to a standard file handle with a line break.
     */
    static func writeln(message text: String, to fileHandle: FileHandle) {

        if let textAsData: Data = (text  + "\r\n").data(using: .utf8) {
            fileHandle.write(textAsData)
        }
    }


    /**
     Write a message to a standard file handle with no line break.
     */
    static func write(message text: String, to fileHandle: FileHandle) {

        if let textAsData: Data = (text).data(using: .utf8) {
            fileHandle.write(textAsData)
        }
    }


    // MARK: Private Functions

    /**
     Write errors and other messages to STD ERR with a line break.
     */
    private static func writeToStderr(_ message: String) {

        writeln(message: message, to: ShellRoutes.Error)
    }


    /**
     Write errors and other messages to STD OUT with a line break.
     */
    private static func writeToStdout(_ message: String) {

        writeln(message: message, to: ShellRoutes.Output)
    }
}


/*
 These extension initialisers are required by `Stdio`.
 */
extension String {

    init(_ colour: Stdio.ShellColour, _ background: Bool = false) {

        self = background ? colour.background() : colour.foreground()
    }


    init(_ style: Stdio.ShellStyle, _ on: Bool = true) {

        self = on ? style.on() : style.off()
    }
}
