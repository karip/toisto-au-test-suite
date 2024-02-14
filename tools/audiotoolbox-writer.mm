//
// audiotoolbox-writer.mm
//
// Writes audio files using the Audio Toolbox API on macOS.
//
// compile: clang++ audiotoolbox-writer.mm -o audiotoolbox-writer -framework Foundation -framework AudioToolbox
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <vector>
#include <string>

std::string toStr(uint32_t fourcc)
{
    std::string res;
    res.push_back((fourcc >> 24) & 255);
    res.push_back((fourcc >> 16) & 255);
    res.push_back((fourcc >> 8) & 255);
    res.push_back((fourcc >> 0) & 255);
    return res;
}

double bitmax(int bits)
{
    return (1LL << bits) - 1;
}

uint64_t packI8(double sample, double override)
{
    double s = sample * bitmax(8) - bitmax(7) - 1;
    if (!isnan(override)) { s = override; }
    SInt8 val = round(s);
    return val;
}

uint64_t packI16(double sample, double override)
{
    double s = sample * bitmax(16) - bitmax(15) - 1;
    if (!isnan(override)) { s = override; }
    SInt16 val = round(s);
    return CFSwapInt16HostToBig(val);
}

uint64_t packI24(double sample, double override)
{
    double s = sample * bitmax(24) - bitmax(23) - 1;
    if (!isnan(override)) { s = override; }
    SInt32 val = round(s);
    return CFSwapInt32HostToBig(val << 8);
}

uint64_t packI32(double sample, double override)
{
    double s = sample * bitmax(32) - bitmax(31) - 1;
    if (!isnan(override)) { s = override; }
    SInt32 val = round(s);
    return CFSwapInt32HostToBig(val);
}

uint64_t packI64(double sample, double override)
{
    double s = sample * bitmax(64) - bitmax(63) - 1;
    if (!isnan(override)) { s = override; }
    SInt32 val = round(s);
    return CFSwapInt64HostToBig(val);
}

void setVectorData(std::vector<uint8_t> &vec, uint64_t offset, uint64_t count, void *data)
{
    vec.resize(offset + count);
    for (uint64_t i = 0; i < count; ++i) {
        vec[offset + i] = ((uint8_t*)data)[i];
    }
}

void writeBytes(const char *filename, AudioFileTypeID atype, AudioStreamBasicDescription &audioDesc,
    std::vector<std::pair<double, double> > sampleData, UInt32 bytesToWrite,
    bool includeFiller)
{
    NSString *fileName = [NSString stringWithUTF8String: filename];
    NSURL *fileURL = [NSURL fileURLWithPath:fileName];

    AudioFileID audioFile;
    uint32_t filler = includeFiller ? 0 : kAudioFileFlags_DontPageAlignAudioData;
    OSStatus error = AudioFileCreateWithURL((CFURLRef)fileURL,
                                            atype,
                                            &audioDesc,
                                            kAudioFileFlags_EraseFile | filler,
                                            &audioFile);
    if (error != noErr) {
        printf("* ERROR: Can't create audio file: %d ('%s')\n", (int32_t)error, toStr(error).c_str());
        exit(-1);
    }

#ifdef WRITE_MARKERS // enable this code block to write test markers
    UInt32 dataSize = NumAudioFileMarkersToNumBytes(1);
    AudioFileMarkerList *markers = (AudioFileMarkerList*)malloc(dataSize);
    markers->mSMPTE_TimeType = 0;
    markers->mNumberMarkers = 1;
    AudioFileMarker *marker = &markers->mMarkers[0];
    memset(marker, 0, sizeof(AudioFileMarker));
    marker->mFramePosition = 0.0;
    marker->mMarkerID = 5;
    marker->mName = CFSTR("MyMark");
    error = AudioFileSetProperty(audioFile, kAudioFilePropertyMarkerList, dataSize, markers);
    if (error != noErr) {
        printf("* ERROR: Can't set marker property\n");
        exit(-1);
    }
    printf("Wrote markers.\n");
    free(markers);
#endif

    std::vector<uint8_t> data;
    for (size_t i = 0; i < sampleData.size(); ++i) {
        std::pair<double, double> sample = sampleData[i];
        uint64_t s = 0;
        if (audioDesc.mBitsPerChannel <= 8) {
            s = packI8(sample.first, sample.second);
        } else if (audioDesc.mBitsPerChannel <= 16) {
            s = packI16(sample.first, sample.second);
        } else if (audioDesc.mBitsPerChannel <= 24) {
            s = packI24(sample.first, sample.second);
        } else if (audioDesc.mBitsPerChannel <= 32) {
            s = packI32(sample.first, sample.second);
        } else if (audioDesc.mBitsPerChannel <= 64) {
            // 64-bit ints are not really supported by Code Audio
            s = packI64(sample.first, sample.second);
        } else {
            printf("* ERROR: bad bit value\n");
            exit(-1);
        }
        SInt64 offset = i * bytesToWrite;
        setVectorData(data, offset, bytesToWrite, &s);
        if (error != noErr) {
            printf("* ERROR: Can't write to audio file\n");
            exit(-1);
        }
    }
    UInt32 byteSize = data.size();
    error = AudioFileWriteBytes(audioFile, false, 0, &byteSize, data.data());
    if (error != noErr) {
        printf("* ERROR: Can't write to audio file\n");
        exit(-1);
    }

    error = AudioFileClose(audioFile);
    if (error != noErr) {
        printf("* ERROR: Can't close audio file\n");
        exit(-1);
    }
}

void writeSamples(const char *filename, AudioFileTypeID atype, AudioStreamBasicDescription &audioDesc,
    std::vector<std::pair<double, double> > sampleData, bool includeFiller)
{
    NSString *fileName = [NSString stringWithUTF8String: filename];
    NSURL *fileURL = [NSURL fileURLWithPath:fileName];

    ExtAudioFileRef audioFile;
    uint32_t filler = includeFiller ? 0 : kAudioFileFlags_DontPageAlignAudioData;
    OSStatus error = ExtAudioFileCreateWithURL((CFURLRef)fileURL,
                                            atype,
                                            &audioDesc,
                                            NULL,
                                            kAudioFileFlags_EraseFile | filler,
                                            &audioFile);
    if (error != noErr) {
        printf("* ERROR: Can't create ext audio file: %d ('%s')\n",
            (int32_t)error, toStr(error).c_str());
        exit(-1);
    }

    int channels = audioDesc.mChannelsPerFrame;

    // app input data format - similar to output format, but using floating point samples

    AudioStreamBasicDescription appDataFormat;
    memset(&appDataFormat, 0, sizeof(AudioStreamBasicDescription));
    appDataFormat.mReserved            = 0;
    appDataFormat.mSampleRate          = audioDesc.mSampleRate;
    appDataFormat.mFramesPerPacket     = 1;
    appDataFormat.mChannelsPerFrame    = channels;
    appDataFormat.mFormatID            = kAudioFormatLinearPCM;

    // use doubles as input data
    appDataFormat.mFormatFlags         = kLinearPCMFormatFlagIsFloat;
    appDataFormat.mBitsPerChannel      = sizeof(double) * 8;
    appDataFormat.mBytesPerFrame       = appDataFormat.mBitsPerChannel / 8 * channels;
    appDataFormat.mBytesPerPacket = appDataFormat.mFramesPerPacket * appDataFormat.mBytesPerFrame;

    size_t propSize = sizeof(appDataFormat);
    error = ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, propSize, &appDataFormat);
    if (error){
        printf("* ERROR: Can't set app format: %d ('%s')\n", (int32_t)error, toStr(error).c_str());
        exit(-1);
    }

    std::vector<double> data;
    for (size_t i = 0; i < sampleData.size(); ++i) {
        std::pair<double, double> sample = sampleData[i];
        double s = sample.first * 2.0 - 1.0;
        if (!isnan(sample.second)) {
            if (audioDesc.mFormatFlags & kLinearPCMFormatFlagIsFloat) {
                s = sample.second;
            } else {
                if (audioDesc.mFormatFlags & kAudioFormatFlagIsSignedInteger) {
                    s = sample.second / pow(2, audioDesc.mBitsPerChannel-1);
                } else { // unsigned integer
                    s = -1.0 + sample.second / pow(2, audioDesc.mBitsPerChannel-1);
                }
            }
        }
        data.push_back(s);
    }

    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mNumberChannels = audioDesc.mChannelsPerFrame;
    bufferList.mBuffers[0].mDataByteSize = data.size() / channels * appDataFormat.mBytesPerFrame;
    bufferList.mBuffers[0].mData = data.data();
    error = ExtAudioFileWrite(audioFile, data.size()/channels, &bufferList);
    if (error != noErr) {
        printf("* ERROR: Can't write to audio file\n");
        exit(-1);
    }

    error = ExtAudioFileDispose(audioFile);
    if (error != noErr) {
        printf("* ERROR: Can't close audio file\n");
        exit(-1);
    }
}

bool string_ends_with(const char *str, const char *end)
{
    size_t slen = strlen(str);
    size_t elen = strlen(end);
    if (slen == 0 || elen == 0 || elen > slen) {
        return false;
    }
    while (slen-- > 0 && elen-- > 0) {
        if (str[slen] != end[elen]) {
            return false;
        }
    }
    return true;
}

int main(int argc, const char *argv[])
{
    if (argc < 5) {
        printf("Usage: audiotoolbox-writer samplerate format channels [-d<durationMS>] [--filler] <filename>\n");
        return -1;
    }

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    double samplerate = atof(argv[1]);
    const char *format = argv[2];
    int channels = atoi(argv[3]);
    int farg = 4;
    const char *filename = argv[farg];
    double duration = 0.1;
    // set duration (-d500)
    if (filename[0] == '-' && filename[1] == 'd') {
        duration = atof(&filename[2]) / 1000;
        farg++;
        filename = argv[farg];
    }
    // enable filler FLLR chunk (--filler)
    bool includeFiller = false;
    if (strcmp(filename, "--filler") == 0) {
        farg++;
        filename = argv[farg];
        includeFiller = true;
    }
    if (channels > 10) {
        printf("* ERROR: too many channels\n");
        exit(-1);
    }

    uint32_t bitsPerChannel = 0;
    bool isSigned = true;
    bool isFloat = false;
    bool isBigEndian = true;
    bool writeRawBytes = false;
    uint32_t formatId = kAudioFormatLinearPCM;
    if (strlen(format) > 3 &&
            (format[0] == 'b' || format[0] == 'l') &&
            format[1] == 'e' &&
            (format[2] == 'i' || format[2] == 'f' || format[2] == 'u') &&
            isnumber(format[3])) {
        isBigEndian = format[0] == 'b';
        if (format[2] == 'i') {
            bitsPerChannel = atoi(&format[3]);
            isSigned = true;
            writeRawBytes = bitsPerChannel != 8 && bitsPerChannel != 16 && bitsPerChannel != 24 && bitsPerChannel != 32;

        } else if (strcmp(&format[2], "f32") == 0) {
            bitsPerChannel = 32;
            isSigned = true;
            isFloat = true;

        } else if (strcmp(&format[2], "f64") == 0) {
            bitsPerChannel = 64;
            isSigned = true;
            isFloat = true;

        } else if (strcmp(&format[2], "u8") == 0) {
            bitsPerChannel = 8;
            isSigned = false;
        }

    } else { // ulaw, alaw, ...
        bitsPerChannel = 16;
        isSigned = true;
        formatId = format[0] << 24 | format[1] << 16 | format[2] << 8 | format[3];
    }

    // create sample data

    double frequency = 440.0;
    int64_t time = 0;
    double waveLen = samplerate / frequency;

    // add channel indicator (10, 20, ..)
    std::vector<std::pair<double, double> > sampleData;
    const int SIG_SAMPLECOUNT = 8;
    for (int i = 0; i < channels*SIG_SAMPLECOUNT; i++) {
        for (int ch = 0; ch < channels; ch++) {
            if (i >= ch*SIG_SAMPLECOUNT && i < ch*SIG_SAMPLECOUNT + SIG_SAMPLECOUNT) {
                if (isFloat) {
                    sampleData.push_back(std::make_pair(0.5 + (ch+1.0) * 0.05, NAN));
                } else {
                    sampleData.push_back(std::make_pair(0, 10.0 * (ch+1.0)));
                }
            } else {
                    sampleData.push_back(std::make_pair(0, 0));
            }
        }
        time++;
    }
    int sigTime = time;
    int64_t totalTime = samplerate * duration;

    // add saw waveform
    double CHANNELSHIFT = 8;
    bool firstwave = true;
    while (time <= totalTime) {
        for (int ch = 0; ch < channels; ch++) {
            int64_t ts = time - sigTime - ch * CHANNELSHIFT;
            double tl = ((double)ts) / waveLen;
            double wt = tl - floor(tl);
            double sample = 1.0 * wt;
            double zero = NAN;
            if (ts < 0) {
                zero = 0;
            }
            // ensure the first wave goes to the max value
            if (ch == 0 && firstwave && time > sigTime) {
                double prevsample = sampleData[sampleData.size()-channels].first;
                if (prevsample > sample) {
                    sampleData[sampleData.size()-channels] = std::make_pair(1.0, NAN);
                    firstwave = false;
                }
            }
            sampleData.push_back(std::make_pair(sample, zero));
        }
        time++;
    }

    // write to file
    AudioFileTypeID atype = kAudioFileAIFFType;
    if (string_ends_with(filename, ".aiff")) {
        atype = kAudioFileAIFFType;
    } else if (string_ends_with(filename, ".aifc")) {
        atype = kAudioFileAIFCType;
    } else if (string_ends_with(filename, ".caf")) {
        atype = kAudioFileCAFType;
    } else if (string_ends_with(filename, ".wav")) {
        // normal 32-bit wav file
        atype = kAudioFileWAVEType;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
        if (strstr(filename, "bw64")) {
            atype = kAudioFileBW64Type;
        } else if (strstr(filename, "rf64")) {
            atype = kAudioFileRF64Type;
        } else if (strstr(filename, "w64f")) {
            atype = kAudioFileWave64Type;
        }
#endif
    } else if (string_ends_with(filename, ".au")) {
        atype = kAudioFileNextType;
    } else {
        printf("* ERROR: bad file type: %s\n", filename);
        exit(-1);
    }

    AudioStreamBasicDescription audioDesc;
    memset(&audioDesc, 0, sizeof(AudioStreamBasicDescription));
    audioDesc.mSampleRate = samplerate;
    audioDesc.mChannelsPerFrame = channels;
    audioDesc.mFramesPerPacket = 1;
    audioDesc.mFormatID = formatId;
    audioDesc.mFormatFlags = kAudioFormatFlagIsPacked;
    if (isBigEndian) {
        audioDesc.mFormatFlags |= kAudioFormatFlagIsBigEndian;
    }
    if (isFloat) {
        audioDesc.mFormatFlags |= kAudioFormatFlagIsFloat;
    } else if (isSigned) {
        audioDesc.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
    }
    audioDesc.mBitsPerChannel = bitsPerChannel;
    audioDesc.mBytesPerFrame = ceil(audioDesc.mBitsPerChannel / 8.0) * channels;
    audioDesc.mBytesPerPacket = audioDesc.mFramesPerPacket * audioDesc.mBytesPerFrame;

    if (writeRawBytes) {
        UInt32 bytesToWrite = ceil(bitsPerChannel / 8.0);
        writeBytes(filename, atype, audioDesc, sampleData, bytesToWrite, includeFiller);
    } else {
        writeSamples(filename, atype, audioDesc, sampleData, includeFiller);
    }

    printf("Wavelength sample count: %lf, max samples %lld, wrote %lld samples for type '%s'.\n",
        waveLen, totalTime, time, toStr(atype).c_str());

    [pool release];

    // memory is not freed properly, we don't care!

    return 0;
}
