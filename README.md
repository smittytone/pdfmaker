# pdfmaker 2.2.0 #

*pdfmaker* is a command line tool for combining multiple JPEG images into a single PDF file.

From version 2.0.0, it can also be used to convert a PDF into separate page images.

For some background on the development of this tool, please see [this blog post](https://smittytone.wordpress.com/2019/10/25/macos-make-pdf-from-images/).

## Installation ##

Build and copy the binary to the `/usr/local/bin` directory.

## Usage ##

### Making PDFs ###

In Terminal, run `pdfmaker --source <path to image(s)> --destination <path to new pdf file> --compress <factor>`

If you omit any of these switches, their default values will be used:

- Source: The directory from which you ran the tool.
- Destination: The Desktop.
- Name: `PDF From Images.pdf`.
- Compression: The native compression of the JPEG source images

You can use `-s`, `-d`, and `-c` as shorthand for the switches above &mdash; `pdfmaker --help` has the details.

#### Image Compression ####

The compression option will compress images before adding them to the PDF. This allows you to reduce the size of the final PDF, as required. Provide an amount in the range 0.0 to 1.0, where 0.0 is maximum compression (lowest quality) and 1.0 is no compression (highest quality).

**Note** Building a PDF from JPEG files means that you are already using compressed images. If those JPEGs are highly compressed, applying a low compression amount to *pdfmaker* will not increase image quality but will make your PDF file larger.

### ‘Breaking’ PDFs ###

To convert a PDF to a set of images, in Terminal, run `pdfmaker --break --source <path to pdf> --destination <path to folder> --resolution <output dpi value>`

You can use `-b`, and `-r` as shorthand for the `--break` and `--resolution` switches. The `-c` switch may also be used to compress the output images.

*pdfmaker* does not delete the source file.

#### Image Resolution ####

The default output resolution is 72dpi (dots per inch). PDFs store page dimensions as points, rather than pixels, enabling device-independent resolution. *pdfmaker* determines image pixel dimensions based on the output resolution and the PDF point dimensions. To get correctly sized images out of a PDF, you need to specify the resolution of the images used to source the PDF. You do this be specifying an appropriate output resolution.

For example, a PDF contains a page sourced from a 2600 x 1600, 300dpi image. Output at 72dpi, this will result in an image of 620 x 400 (2600 * 27 / 300). To get the correct pixel size back, add `-r 300` to the command line. This will yield a 2600 x 1600, 300dpi output image.

If you don’t know the source image dpi resolution, experiment with `-r` values until you get output of the size you require.

### Examples ###

```
pdfmaker --source ~/Documents/'Project X'/Images --destination ~/Documents/PDFs/'Project X.pdf'
```

This will merge all of the images files in `~/Documents/Project X/Images` into a file called `Project X.pdf` which is placed in `~/Documents/PDFs`.

```
pdfmaker --source ~/Documents/'Project X'/Images --destination ~/Documents/PDFs/'Project X.pdf' --compress 0.5
```

This will merge all of the images files in `~/Documents/Project X/Images` into a file called `Project X.pdf` which is placed in `~/Documents/PDFs`. The compilation process will compress images to 50% JPEG quality.

```
pdfmaker --source ~/Documents/'Project X'/Images/cover.jpg --destination ~/Documents/PDFs
```

This converts the image `cover.jpg` into a file called `PDF From Images.pdf` (as no destination filename is specified) that is placed in `~/Documents/PDFs`.

```
pdfmaker --break --source ~/Documents/PDFs/'Project X.pdf' --compress 0.4 --resolution 200
```

This converts `Project X.pdf` to a series of images that will be written to the desktop (the default destination). This images will be highly compressed and output at a resolution of 200dpi.

## Release Notes ##

- 2.2.0 *Unreleased*
    - Support adding PNG and TIFFs to PDFs.
    - More informative error reporting.
- 2.1.0 *09 July 2020*
    - Better reporting of bad arguments.
    - Add '--version' option.
- 2.0.0 *14 November 2019*
    - Add PDF-to-images functionality.
- 1.1.0 *28 October 2019*
    - Allow the user to select a single source image, not just source directories.
    - Allow the user to name the target file as part of the target path.
        - Remove the `--name` switch.
    - Ignore dot files in the source image search.
    - Support easier notarization.
- 1.0.0 *18 October 2019*
    - Initial public release.

## Copyright ##

*pdfmaker* is copyright &copy; 2020, Tony Smith. The source code is licensed under the terms of the MIT licence.
