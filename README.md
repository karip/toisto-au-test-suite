
# Toisto AU Test Suite

This is an unofficial AU audio file test suite.

## Usage

The `toisto-runner.py` script runs the test suite for the command given to it.

Here's examples running the test suite for the macOS AudioToolBox framework and
Python sunau module. AudioToolBox requires building its tester before running it
and python sunau is available in Python versions less than 3.13.

    # for macOS
    cd tools
    clang++ ... # see audiotoolbox-au-tester.mm for compilation instructions
    cd ..
    python3 toisto-runner.py -v tools/audiotoolbox-au-tester
    # Total 84: 66 passed, 18 failed, 21 invalid, 0 ignored.

    python3 toisto-runner.py -v tools/python3-au-tester.py
    # Total 84: 61 passed, 23 failed, 21 invalid, 0 ignored.

[The results for macOS 14.3 AudioToolBox](result-audiotoolbox-au-tester.md)
running audiotoolbox-au-tester.

## Test cases

The test files are under the `tests` folder. The folder contains subfolders:

 - `au` - contains valid AU test files
 - `exported` - contains test files exported from various apps
 - `invalid` - contains invalid AU files

The `invalid` folder contains invalid AU files. The readers may or may not read them,
but hopefully they won't crash reading them.

Note: Some apps (Audacity and QuickTime Player 7) export only a 24-byte header, but
the [spec](https://docs.oracle.com/cd/E36784_01/html/E36882/au-4.html) says that
the minimum header size is 28 bytes. So, those apps are writing invalid AU files,
but most apps seem to be able to read them.

## Expected results (json files)

Each audio file has a json file describing the expected result for reading
the audio file. The properties in the json file are:

 - `testinfo` - meta info about the test
   - `description` - short description of the test file
   - `notes` - additional notes about the test
   - `software` - name of the software used to create the file, if this is
                  missing, then the file was created manually in a hex editor
   - `version` - version of the software
   - `platform` - platform used to run the software ("macOS 12.4" / "Windows 7" ..)
   - `command` - command line tool and its arguments used to create the file
 - `result` - the test is a normal test if this is missing, `ignore` to ignore the test,
              `invalid` if the test file is an invalid file
 - `format` - always `au`
 - `sampleRate` - sample rate
 - `channels` - number of channels
 - `codec` - the compression type or type of uncompressed pcm sample data:
    `pcm_bei`=signed big-endian integer, `pcm_lei`=signed little-endian integer,
    `pcm_bef`=signed big-endian floating point
    `<number>`=encoding number (0-27) for non-PCM encodings (2-7)
 - `sampleSize` - for uncompressed encodings, the sample size in bits 8, 16, 24, 32 or 64, and
                  for compressed encodings, the decoded sample size (0 for unknown sizes)
 - `desc` - a list of bytes in the description info field (only for description tests)
 - `samplesPerChannel` - the number of samples per channel after samples have been decoded
 - `tolerance` - how much sample values may differ from the expected values, default is 0
 - `startSamples` - a list of channels containing a list of samples (only the first 100-300 samples)
 - `endSamples` - a list of channels containing a list of samples (only the last 30 samples)

See [reftemplate.json](reftemplate.json) for examples for all the fields.

toisto-runner.py will compare each of these fields (except testinfo) against
the values returned by the command. If the fields match, the test passes.
If the command returns "-unsupported-", it means that the field is not
supported by the command and it won't affect the result of the test.

## Reference sample data

The `startSamples` and `endSamples` properties in the json file contain samples
for each channel. The range of values depends on `sampleSize`:

| Sample size |                Range                |
| :---------: | :---------------------------------: |
|      8      |             [-128, 127]             |
|     16      |           [-32768, 32767]           |
|     24      |         [-8388608, 8388607]         |
|     32      | [-2147483648, 2147483647] or floats |
|     64      |               floats                |

## Other test files

 - [AU Sample Files](https://www.mmsp.ece.mcgill.ca/Documents/AudioFormats/AU/Samples.html)

## References

 - [The "spec": Oracle Solaris AU man page](https://docs.oracle.com/cd/E36784_01/html/E36882/au-4.html)
 - [Oracle Solaris audioconvert](https://docs.oracle.com/cd/E36784_01/html/E36870/audioconvert-1.html)
 - [Audio File Formats FAQ: File Formats](https://web.archive.org/web/20230223152815/https://sox.sourceforge.net/AudioFormats-11.html#ss11.2)
 - [NeXT soundstruct.h](https://github.com/johnsonjh/NeXTDSP/blob/26d2b31a6fb4bc16d55ebe17824cd2d6f9edfc7b/sound-33/soundstruct.h#L4)
 - [NeXT/Sun soundfile format](http://soundfile.sapp.org/doc/NextFormat/)
 - [Apple AudioToolBox framework](https://developer.apple.com/documentation/audiotoolbox/)
 - [Python3 sunau module](https://docs.python.org/3/library/sunau.html)

## License

All test files and source code is licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
