# pdfmaker 1.0.0 #

*pdfmaker* is a command line tool for combining multiple JPEG images into a single PDF file.

## Installation ##

Build and copy the binary to the `/usr/local/bin` directory.

## Usage ##

In Terminal, run `pdfmaker --source <image source directory> --destination <pdf_save_directory> --name <pdf_filename>`

If you omit any of these switches, their default values will be used:

- Source: The directory from which you ran the tool.
- Destination: The Desktop.
- Name: `PDF From Images`.

You can use `-s`, `-d` and `-n` as shorthand for the switches above &mdash; `pdfmaker --help` has the details.

### Example ###

```
pdfmaker --source ~/Documents/'Project X'/Images --destination ~/Documents/PDFs --name 'Project X'
```

This will merge all of the images files in `~/Documents/Project X/Images` into a file called `Project X.pdf` which is placed in
`~/Documents/PDFs`.

## Release Notes ##

- 1.0.0 &mdash; *Unreleased*
    - Initial public release.

## Copyright ##

*pdfmaker* is copyright &copy; 2019, Tony Smith. The source code is licensed under the terms of the MIT licence.
