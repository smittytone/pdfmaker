# pdfmaker Tests #

The script `testpdfmaker.zsh` performs a sequence of tests on a *pdfmaker* binary. It uses the files in the `source` directory.

### Usage ###

1. `cd {path/to/pdfmaker/tests}`
1. `./testpdfmaker.zsh {path/to/pdfmaker/binary}`

### Outcome ###

If any of tests fail, please [report this as a gitHub issue](https://github.com/smittytone/pdfmaker/issues), indicating which test failed and providing any information you have about any changes you made to the test script or the imageprep source.

If all the tests pass — the expected outcome — remember to delete the test artifacts from the `tests` directory before re-running the tests.
