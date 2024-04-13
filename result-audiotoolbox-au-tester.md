
# Results for running audiotoolbox-au-tester on macOS 14.4

~~~

> python3 toisto-runner.py -v tools/audiotoolbox-au-tester

Testing command: tools/audiotoolbox-au-tester
OK    : tests/au/channels-1.au
OK    : tests/au/channels-10.au
OK    : tests/au/channels-2-bei16.au
OK    : tests/au/channels-2-float.au
OK    : tests/au/channels-2.au
OK    : tests/au/channels-4.au
OK    : tests/au/datasize-0.au
OK    : tests/au/datasize-1.au

FAIL  : tests/au/datasize-ffffffff.au
 - values differ for "samplesPerChannel", got: '4439', expected: '4411'
 - values differ for "endSamples", channel 0, index 0, got: 105, expected: 33

OK    : tests/au/desc-4-ascii.au
 - unsupported: desc

OK    : tests/au/desc-5-ascii.au
 - unsupported: desc

OK    : tests/au/desc-5-bytes.au
 - unsupported: desc

OK    : tests/au/desc-8-ascii.au
 - unsupported: desc

OK    : tests/au/encoding-01-ulaw.au
OK    : tests/au/encoding-02-linear-8.au
OK    : tests/au/encoding-03-linear-16.au
OK    : tests/au/encoding-04-linear-24.au
OK    : tests/au/encoding-05-linear-32.au
OK    : tests/au/encoding-06-float-nan-inf.au
OK    : tests/au/encoding-06-float-wide-range.au
OK    : tests/au/encoding-06-float.au
OK    : tests/au/encoding-07-double-nan-inf.au
OK    : tests/au/encoding-07-double-wide-range.au
OK    : tests/au/encoding-07-double.au

FAIL  : tests/au/encoding-23-g721.au
* ERROR: can't open file: tests/au/encoding-23-g721.au (fmt?)
 - process returned non-zero exit status: 255

FAIL  : tests/au/encoding-24-g722.au
* ERROR: can't open file: tests/au/encoding-24-g722.au (fmt?)
 - process returned non-zero exit status: 255

FAIL  : tests/au/encoding-25-g723.3.au
* ERROR: can't open file: tests/au/encoding-25-g723.3.au (fmt?)
 - process returned non-zero exit status: 255

FAIL  : tests/au/encoding-26-g723.5.au
* ERROR: can't open file: tests/au/encoding-26-g723.5.au (fmt?)
 - process returned non-zero exit status: 255

OK    : tests/au/encoding-27-alaw.au
OK    : tests/au/samplerate-0.au
OK    : tests/au/samplerate-1.au
OK    : tests/au/samplerate-11025.au
OK    : tests/au/samplerate-22050.au
OK    : tests/au/samplerate-2900000.au
OK    : tests/au/samplerate-384000.au
OK    : tests/au/samplerate-44100.au
OK    : tests/au/samplerate-5298.au

FAIL  : tests/au/samplerate-7fffffff.au
* ERROR: can't open file: tests/au/samplerate-7fffffff.au (fmt?)
 - process returned non-zero exit status: 255

FAIL  : tests/au/samplerate-ffffffff.au
 - values differ for "sampleRate", got: '65535', expected: '4294967295'

OK    : tests/exported/audacity-float.au

FAIL  : tests/exported/audacity-g721-32kbs.au
* ERROR: can't open file: tests/exported/audacity-g721-32kbs.au (fmt?)
 - process returned non-zero exit status: 255

FAIL  : tests/exported/audacity-g723.3-24kbs.au
* ERROR: can't open file: tests/exported/audacity-g723.3-24kbs.au (fmt?)
 - process returned non-zero exit status: 255

FAIL  : tests/exported/audacity-g723.5-40kbs.au
* ERROR: can't open file: tests/exported/audacity-g723.5-40kbs.au (fmt?)
 - process returned non-zero exit status: 255

OK    : tests/exported/audacity-i16.au
OK    : tests/exported/audioconvert-alaw.au

FAIL  : tests/exported/audioconvert-g721.au
* ERROR: can't open file: tests/exported/audioconvert-g721.au (fmt?)
 - process returned non-zero exit status: 255

FAIL  : tests/exported/audioconvert-g723.3.au
* ERROR: can't open file: tests/exported/audioconvert-g723.3.au (fmt?)
 - process returned non-zero exit status: 255

OK    : tests/exported/audioconvert-i16.au
OK    : tests/exported/audioconvert-ulaw.au
OK    : tests/exported/ffmpeg-desc.au
 - unsupported: desc

OK    : tests/exported/ffmpeg-i16.au
OK    : tests/exported/python3-i16.au
OK    : tests/exported/python3-i24.au
OK    : tests/exported/python3-i32.au
OK    : tests/exported/python3-i8.au
OK    : tests/exported/python3-ulaw.au

FAIL  : tests/exported/quicktime5-alaw.au
 - values differ for "sampleRate", got: '44100', expected: '4294945860'

FAIL  : tests/exported/quicktime5-f32.au
 - values differ for "sampleRate", got: '44100', expected: '4294945860'

FAIL  : tests/exported/quicktime5-f64.au
 - values differ for "sampleRate", got: '44100', expected: '4294945860'

FAIL  : tests/exported/quicktime5-i16.au
 - values differ for "sampleRate", got: '44100', expected: '4294945860'

FAIL  : tests/exported/quicktime5-i8.au
 - values differ for "sampleRate", got: '44100', expected: '4294945860'

FAIL  : tests/exported/quicktime5-ulaw.au
 - values differ for "sampleRate", got: '44100', expected: '4294945860'

OK    : tests/exported/quicktime7-i8.au
OK    : tests/exported/sndconvert-double.au
OK    : tests/exported/sndconvert-float.au
OK    : tests/exported/sndconvert-linear-16.au
OK    : tests/exported/sndconvert-linear-8.au
OK    : tests/exported/sndconvert-mulaw.au

(FAIL): tests/invalid/invalid-channels-0.au
* ERROR: can't open file: tests/invalid/invalid-channels-0.au (fmt?)
 - process returned non-zero exit status: 255

(FAIL): tests/invalid/invalid-channels-80000000.au
* ERROR: can't open file: tests/invalid/invalid-channels-80000000.au (fmt?)
 - process returned non-zero exit status: 255

(FAIL): tests/invalid/invalid-channels-ffffffff.au
* ERROR: can't open file: tests/invalid/invalid-channels-ffffffff.au (fmt?)
 - process returned non-zero exit status: 255

(OK)  : tests/invalid/invalid-desc-3-bytes.au
 - unsupported: desc

(FAIL): tests/invalid/invalid-encoding.au
* ERROR: can't open file: tests/invalid/invalid-encoding.au (fmt?)
 - process returned non-zero exit status: 255

(OK)  : tests/invalid/invalid-extra-garbage-at-end.au

(FAIL): tests/invalid/invalid-file-size-23.au
* ERROR: can't open file: tests/invalid/invalid-file-size-23.au (fmt?)
 - process returned non-zero exit status: 255

(OK)  : tests/invalid/invalid-file-size-24.au
(OK)  : tests/invalid/invalid-file-size-27.au

(FAIL): tests/invalid/invalid-no-data-for-channels.au
 - values differ for "samplesPerChannel", got: '0', expected: '1'
 - values differ for "startSamples", channel 0, index 0, got: none, expected: 10
 - values differ for "endSamples", channel 0, index 0, got: none, expected: 10

(OK)  : tests/invalid/invalid-not-enough-audio-data.au
(OK)  : tests/invalid/invalid-offset-0.au
(OK)  : tests/invalid/invalid-offset-23.au
(OK)  : tests/invalid/invalid-offset-24.au
(OK)  : tests/invalid/invalid-offset-27.au
(OK)  : tests/invalid/invalid-offset-4.au
(OK)  : tests/invalid/invalid-offset-5-with-garbage.au
(OK)  : tests/invalid/invalid-offset-8.au
(OK)  : tests/invalid/invalid-offset-80000000.au
(OK)  : tests/invalid/invalid-offset-after-end.au
(OK)  : tests/invalid/invalid-offset-ffffffff.au

Total 89: 50 passed, 18 failed, 21 invalid, 0 ignored.

~~~
