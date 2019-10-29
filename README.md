# pdfmaker 1.1.0 #

*pdfmaker* is a command line tool for combining multiple JPEG images into a single PDF file.

## Installation ##

Build and copy the binary to the `/usr/local/bin` directory.

## Usage ##

In Terminal, run `pdfmaker --source <path to image(s)> --destination <path to new pdf file> --compress <factor>`

If you omit any of these switches, their default values will be used:

- Source: The directory from which you ran the tool.
- Destination: The Desktop.
- Name: `PDF From Images.pdf`.
- Compression: The native compression of the JPEG source images

You can use `-s`, `-d`, and `-c` as shorthand for the switches above &mdash; `pdfmaker --help` has the details.

### Compression ###

The compression option will compress images before adding them to the PDF. This allows you to reduce the size of the final PDF, as required. Provide an amount in the range 0.0 to 1.0, where 0.0 is maximum compression (lowest quality) and 1.0 is no compression (highest quality).

**Note** Building a PDF from JPEG files means that you are already using compressed images. If those JPEGs are highly compressed, applying a low compression amount to *pdfmaker* will not increase image quality but will make your PDF file larger.

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

## Release Notes ##

- 1.1.0 &mdash; *28 October 2019*
    - Allow the user to select a single source image, not just source directories.
    - Allow the user to name the target file as part of the target path.
        - Remove the `--name` switch.
    - Ignore dot files in the source image search.
    - Support easier notarization.
- 1.0.0 &mdash; *18 October 2019*
    - Initial public release.

## Copyright ##

*pdfmaker* is copyright &copy; 2019, Tony Smith. The source code is licensed under the terms of the MIT licence.
