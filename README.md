# pdfmaker 2.5.1 #

*pdfmaker* is a command line tool for combining multiple images into a single PDF file. It supports JPEG, HEIC, PNG, TIFF, BMP and WebP as source-image formats.

It can also be used to convert a PDF into separate page JPEG images or to a single text file (if it contains actual text, not merely images of textual content).

For some background on the development of this tool, [please see this blog post](https://smittytone.wordpress.com/2019/10/25/macos-make-pdf-from-images/).

*pdfmaker requires macOS 12 or above.

## Installation ##

Build and copy the binary to the `/usr/local/bin` directory. You will first need to retrieve the git submodule used by the code.

## Usage ##

### Making PDFs ###

In Terminal, run `pdfmaker --source <path to image(s)> --destination <path to new pdf file> --compress <factor>`

If you omit any of these switches, their default values will be used:

- Source: The directory from which you ran the tool.
- Destination: The Desktop.
- Name: `PDF From Images.pdf`.
- Compression: The native compression of the JPEG source images

You can use `-s`, `-d`, and `-c` as shorthand for the switches above &mdash; `pdfmaker --help` has the details.

Use the `--createdirs` switch to cause *pdfmaker* to create intermediate directories to the target. This is not the default. If this switch is not used, *pdfmaker* will exit with a ‘missing directory’ error.

Use the `--name` switch to provide a filename for your file if you are making a PDF and your destination is a directory.

#### Image Compression ####

The compression option will compress images before adding them to the PDF. This allows you to reduce the size of the final PDF, as required. Provide an amount in the range 0.0 to 1.0, where 0.0 is maximum compression (lowest quality) and 1.0 is no compression (highest quality).

**Note** Building a PDF from JPEG files means that you are already using compressed images. If those JPEGs are highly compressed, applying a low compression amount to *pdfmaker* will not increase image quality but will make your PDF file larger.

#### Metadata ####

From 2.5.0, you can add metadata — title, subject and/or author — to generated PDFs by including them at the command line:

```
pdfmaker --source ~/Documents/'Project X'/Images --destination ~/Documents/PDFs/'Project X.pdf' --title 'My Photos' --author 'A Photographer' --subject Photography
```

#### Encryption ####

From 2.5.0, use the `--password` option to specify an admin password for the generated PDF. This will allow the PDF to be viewed, but encrypt it and (on well behaved software) prevent it from being printed, its content copied and so on. These accessibility settings can only be changed after entering the admin password. 

### ‘Breaking’ PDFs ###

To convert a PDF to a set of images, in Terminal, run `pdfmaker --break --source <path to pdf> --destination <path to folder> --resolution <output dpi value>`

You can use `-b`, and `-r` as shorthand for the `--break` and `--resolution` switches. The `-c` switch may also be used to compress the output images.

To extract the text from a PDF, run `pdfmaker --break --text --source <path to pdf> --destination <path to folder|path to output file>`

You can use `-t` as shorthand for `--text`.

If you don’t specify a destination, *pdfmaker* uses the Desktop as the target folder for image extraction. For text extraction, the Desktop is also used as the destination but the file will take the same name as the source but appended with `.txt` in place of `.pdf`. 

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

## Contributions ##

Contributions are welcome, but pull requests can only be accepted when they target the `develop` branch. PRs targeting `main` will be rejected.

## Release Notes ##

See [CHANGELOG.md](./CHANGELOG.md)

## Copyright ##

*pdfmaker* is copyright © 2026, Tony Smith. The source code is licensed under the terms of the MIT licence.
