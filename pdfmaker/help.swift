/*
    pdfmaker
    help.swift

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
import Clicore


extension Pdfmaker {

    /**
     Display the help screen.
     */
    internal static func showHelp() {

        let helpText = """

        Convert a directory of images or a specified image to a single PDF file, or
        expand a single PDF file into a collection of image files.
        
        \(String(.bold))USAGE\(String(.normal))
            pdfmaker [-s path] [-d path] [-c value] [-r value] [-b ] [-v] [-h]
        
        \(String(.bold))OPTIONS\(String(.normal))
            -s | --source      {path}    The path to the images or an image. Default: current folder
            -d | --destination {path}    Where to save the new PDF. The file name is optional.
                                         Default: ~/Desktop folder/\'PDF From Images.pdf\'.
            -n | --name        {name}    Specify the target file name. Only used when your destination
                                         is a directory.
            -c | --compress    {amount}  Apply an image compression filter to the generated PDF:
                                         0.0 = maximum compression, lowest image quality.
                                         1.0 = no compression, best image quality.
                 --createdirs            Make target intermediate directories if they do not exist.
                 --title                 Set the title of the generated PDF.
                 --subject               Add subject information to the generated PDF.
                 --author                Set the author of the generated PDF.
                 --password              Specify an admin password, used to encrypt the generated PDF.
            -b | --break                 Break a PDF into JPEG images unless the --text flag is set.
            -r | --resolution  {dpi}     The output resolution of extracted images. Max: 9999.
            -t | --text                  Extract the source’s text and don’t generate images.
            -v | --verbose               Show progress information. Otherwise only errors are shown.
            -h | --help                  This help screen.
                 --version               Show pdfmaker version information.
        
        \(String(.bold))EXAMPLES\(String(.normal))")
            pdfmaker --source "$IMAGES_DIR" --destination "$PDFS_DIR"/\'Project X.pdf\' --compress 0.8
            pdfmaker --source "$IMAGES_DIR"/cover.jpg --destination "$PDFS_DIR" --compress 0.5
            pdfmaker --break --source "$PDFS_DIR"/\'Project X.pdf\' --destination "$IMAGES_DIR"
            pdfmaker --break --text --source "$PDFS_DIR"/\'Project X.pdf\' --destination "$HOME/report.txt"
        
        \(String(.italic))https://github.com/smittytone/pdfmaker\(String(.normal))
        """

        showHeader()
        Stdio.report(helpText)
    }


    /**
     Display the app's version and other information.

     FROM 2.1.0
     */
    internal static func showHeader() {

        let version = getVersion(withBuild: true)
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "pdfmaker"
        Stdio.report("\(String(.bold))\(appName) \(version)\(String(.normal))")
        Stdio.report("Copyright © 2026, Tony Smith (@smittytone). Source code available under the MIT licence.")
    }


    /**
     Get the version number.

     FROM 2.5.0

     - returns: The version as a string
     */
    internal static func getVersion(withBuild: Bool = false) -> String {

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? SWIFT_BUILD_PROCESS_VERSION
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "\(SWIFT_BUILD_PROCESS_BUILD)"
        return withBuild ? "\(version) (\(build))" : version
    }

}
