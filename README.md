# pdfmaker 1.0.0 #

*pdfmaker* is a command line tool for combining multiple JPEG images into a single PDF file.

## Installation ##

Build and copy the binary to the `/usr/local/bin` directory.

## Usage ##

In Terminal, run `pdfmaker --source <image source directory> --destination <pdf_save_directory> --name <pdf_filename> --compress <amount>`

If you omit any of these switches, their default values will be used:

- Source: The directory from which you ran the tool.
- Destination: The Desktop.
- Name: `PDF From Images`.
- Compression: The native compression of the JPEG source images

You can use `-s`, `-d`, `-n` and `-c` as shorthand for the switches above &mdash; `pdfmaker --help` has the details.

### Compression ###

The compression option will compress images before adding them to the PDF. This allows you to reduce the size of the final PDF, as required. Provide an amount in the range 0.0 to 1.0, where 0.0 is maximum compression (lowest quality) and 1.0 is no compression (highest quality).

**Note** Building a PDF from JPEG files means that you are already using compressed images. If those JPEGs are highly compressed, applying a low compression amount to *pdfmaker* will not increase image quality but will make your PDF file larger.

### Examples ###

```
pdfmaker --source ~/Documents/'Project X'/Images --destination ~/Documents/PDFs --name 'Project X'
```

This will merge all of the images files in `~/Documents/Project X/Images` into a file called `Project X.pdf` which is placed in
`~/Documents/PDFs`.

```
pdfmaker --source ~/Documents/'Project X'/Images --destination ~/Documents/PDFs --name 'Project X' --compress 0.5
```

This will merge all of the images files in `~/Documents/Project X/Images` into a file called `Project X.pdf` which is placed in
`~/Documents/PDFs`. The compilation process will compress images to 50% JPEG quality.

## Release Notes ##

- 1.0.0 &mdash; *Unreleased*
    - Initial public release.

## Copyright ##

*pdfmaker* is copyright &copy; 2019, Tony Smith. The source code is licensed under the terms of the MIT licence.
