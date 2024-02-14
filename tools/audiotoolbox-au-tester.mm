//
// audiotoolbox-au-tester.mm
//
// Tests how Audio Toolbox API reads audio files on macOS.
//
// compile: clang++ audiotoolbox-au-tester.mm -o audiotoolbox-au-tester -framework Foundation -framework AudioToolbox
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <string>
#include <vector>
#include <sstream>
#include <map>

void printerr(const char *str)
{
    fprintf(stderr, "* ERROR: %s", str);
}

std::string toStr(uint32_t fourcc)
{
    std::string res;
    res.push_back((fourcc >> 24) & 255);
    res.push_back((fourcc >> 16) & 255);
    res.push_back((fourcc >> 8) & 255);
    res.push_back((fourcc >> 0) & 255);
    return res;
}

std::string cfStringToStdString(const void *cfString)
{
    std::string stdstr = std::string([(NSString *)cfString UTF8String]);
    // escape control chars (0x80-0x9f)
    const char hex[] = {
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
    };
    std::string escaped;
    for (size_t i = 0; i < stdstr.size(); ++i) {
        unsigned char c = stdstr[i];
        unsigned char nc = stdstr[i+1];
        if (c == 0xc2 && nc >= 0x80 && nc < 0xa0) {
            escaped.push_back('\\');
            escaped.push_back('u');
            escaped.push_back('0');
            escaped.push_back('0');
            escaped.push_back(hex[nc >> 4]);
            escaped.push_back(hex[nc & 15]);
            i++;
        } else {
            escaped.push_back(c);
        }
    }
    return escaped;
}

// compressed codecs

UInt32 getExtPropertySize(ExtAudioFileRef fileID, AudioFilePropertyID propertyId)
{
    UInt32 size = 0;
    OSStatus err = ExtAudioFileGetPropertyInfo(fileID, propertyId, &size, NULL);
    if (err != noErr) {
        fprintf(stderr, "Failed to the read size for a property: '%s'\n", toStr(propertyId).c_str());
        exit(-1);
    }
    return size;
}

enum DataType { DataTypeInt8, DataTypeInt16, DataTypeInt24, DataTypeInt32, DataTypeF32 };

std::vector<std::vector<double> > readExtAudioData(const char *filename)
{
    ExtAudioFileRef fileID = nil;
    OSStatus err = noErr;

    NSString *path = [NSString stringWithUTF8String: filename];
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    err = ExtAudioFileOpenURL((CFURLRef)fileURL, &fileID);
    if (err != noErr) {
        fprintf(stderr, "* ERROR: can't open file: %s (%s)\n", filename, toStr(err).c_str());
        exit(-1);
    }

    // get number of frames
    SInt64 frames = 0;
    UInt32 fsize = getExtPropertySize(fileID, kExtAudioFileProperty_FileLengthFrames);
    err = ExtAudioFileGetProperty(fileID, kExtAudioFileProperty_FileLengthFrames, &fsize, &frames);
    if (err != noErr) {
        printerr("Failed to read kExtAudioFileProperty_FileLengthFrames\n");
        exit(-1);
    }

    AudioStreamBasicDescription audesc;
    UInt32 dfsize = getExtPropertySize(fileID, kExtAudioFileProperty_FileDataFormat);
    err = ExtAudioFileGetProperty(fileID, kExtAudioFileProperty_FileDataFormat, &dfsize, &audesc);
    if (err != noErr) {
        printerr("Failed to read kExtAudioFileProperty_FileDataFormat\n");
        exit(-1);
    }

    // read channel layout
    UInt32 clsize = getExtPropertySize(fileID, kExtAudioFileProperty_FileChannelLayout);
    UInt8* channelLayoutBuffer = (UInt8*)malloc(clsize);
    AudioChannelLayout *channelLayout = (AudioChannelLayout*)(channelLayoutBuffer);
    err = ExtAudioFileGetProperty(fileID, kExtAudioFileProperty_FileChannelLayout, &clsize, channelLayout);
    if (err != noErr) {
        printerr("Failed to read kAudioFilePropertyChannelLayout\n");
        exit(-1);
    }
    if (channelLayout->mChannelLayoutTag != 0) {
        printf("    \"chan\": {\n");
        printf("        \"channelLayoutTag\": %d,\n", (uint32_t)channelLayout->mChannelLayoutTag);
        printf("        \"channelBitmap\": %d,\n", (uint32_t)channelLayout->mChannelBitmap);
        printf("        \"channelDescriptions\": [\n");
        for (size_t i = 0; i < channelLayout->mNumberChannelDescriptions; ++i) {
            printf("            { \"label\": %d, \"flags\": %d, \"coordinates\": [ %f, %f, %f ] }\n",
                (uint32_t)channelLayout->mChannelDescriptions[i].mChannelLabel,
                (uint32_t)channelLayout->mChannelDescriptions[i].mChannelFlags,
                channelLayout->mChannelDescriptions[i].mCoordinates[0],
                channelLayout->mChannelDescriptions[i].mCoordinates[1],
                channelLayout->mChannelDescriptions[i].mCoordinates[2]);
        }
        printf("        ]\n");
        printf("    },\n");
    }

    int channels = audesc.mChannelsPerFrame;

    std::vector<std::vector<double> > sampleChannelData;
    sampleChannelData.resize(channels);

    AudioStreamBasicDescription appDataFormat;
    memset(&appDataFormat, 0, sizeof(AudioStreamBasicDescription));
    appDataFormat.mReserved            = 0;
    appDataFormat.mSampleRate          = audesc.mSampleRate;
    appDataFormat.mFramesPerPacket     = 1;
    appDataFormat.mChannelsPerFrame    = channels;
    appDataFormat.mFormatID            = kAudioFormatLinearPCM;

    // by default, print out floats for compressed data
    appDataFormat.mFormatFlags         = kLinearPCMFormatFlagIsFloat;
    appDataFormat.mBitsPerChannel      = sizeof(float) * 8;
    DataType dataType = DataTypeF32;
    bool isSigned = true;

    if (audesc.mFormatID == kAudioFormatLinearPCM && !(audesc.mFormatFlags & kLinearPCMFormatFlagIsFloat)) {
        isSigned = audesc.mFormatFlags & kAudioFormatFlagIsSignedInteger;
        uint32_t sign = audesc.mFormatFlags & kAudioFormatFlagIsSignedInteger;
        if (audesc.mBitsPerChannel <= 8) {
            appDataFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | sign;
            appDataFormat.mBitsPerChannel = 8;
            dataType = DataTypeInt8;

        } else if (audesc.mBitsPerChannel <= 16) {
            appDataFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | sign;
            appDataFormat.mBitsPerChannel = 16;
            dataType = DataTypeInt16;

        } else if (audesc.mBitsPerChannel <= 24) {
            appDataFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | sign;
            appDataFormat.mBitsPerChannel = 32;
            dataType = DataTypeInt24;

        } else if (audesc.mBitsPerChannel <= 32) {
            appDataFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | sign;
            appDataFormat.mBitsPerChannel = 32;
            dataType = DataTypeInt32;
        }
    }

    // ulaw, alaw, ima4, Qclp, QDMC, QDM2, MAC3, MAC6, agsm prints out 16-bit ints
    if (audesc.mFormatID == kAudioFormatULaw
        || audesc.mFormatID == kAudioFormatALaw
        || audesc.mFormatID == kAudioFormatAppleIMA4
        || audesc.mFormatID == kAudioFormatQUALCOMM
        || audesc.mFormatID == kAudioFormatQDesign
        || audesc.mFormatID == kAudioFormatQDesign2
        || audesc.mFormatID == kAudioFormatMACE3
        || audesc.mFormatID == kAudioFormatMACE6
        || audesc.mFormatID == 0x6167736d) { // "agsm"
        appDataFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
        appDataFormat.mBitsPerChannel = 16;
        dataType = DataTypeInt16;
    }

    appDataFormat.mBytesPerFrame = appDataFormat.mBitsPerChannel / 8 * channels;
    appDataFormat.mBytesPerPacket = appDataFormat.mFramesPerPacket * appDataFormat.mBytesPerFrame;

    int bytesPerSample = audesc.mBitsPerChannel / 8;
    size_t propSize = sizeof(appDataFormat);
    err = ExtAudioFileSetProperty(fileID, kExtAudioFileProperty_ClientDataFormat, propSize, &appDataFormat);
    if (err){
        printerr("Can't set app format\n");
        exit(-1);
    }
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mNumberChannels = channels;
    size_t datasize = frames * appDataFormat.mBytesPerFrame;
    char *data = (char *)malloc(datasize);
    bufferList.mBuffers[0].mDataByteSize = datasize;
    bufferList.mBuffers[0].mData = data;
    UInt32 total_frames_read = 0;
    while (total_frames_read < frames) {
        bufferList.mBuffers[0].mData = data + total_frames_read * appDataFormat.mBytesPerFrame;
        UInt32 frame_count_32 = frames - total_frames_read;
        // takes in frame count to read (frame_count_32) and returns how many was read (frame_count_32)
        err = ExtAudioFileRead(fileID, &frame_count_32, &bufferList);
        if (err != noErr) {
            printerr("Error reading sample data\n");
            exit(-1);
        }
        if (frame_count_32 == 0) {
            break;
        }
        total_frames_read += frame_count_32;
    }
    size_t pos = 0;
    while (pos < frames * channels) {
        for (int ch = 0; ch < channels; ++ch) {
            if (dataType == DataTypeInt8) {
                if (isSigned) {
                    int8_t *d = (int8_t *)data;
                    sampleChannelData[ch].push_back(d[pos]);
                } else {
                    uint8_t *d = (uint8_t *)data;
                    sampleChannelData[ch].push_back(d[pos]);
                }

            } else if (dataType == DataTypeInt16) {
                if (isSigned) {
                    int16_t *d = (int16_t *)data;
                    sampleChannelData[ch].push_back(d[pos]);
                } else {
                    uint16_t *d = (uint16_t *)data;
                    sampleChannelData[ch].push_back(d[pos]);
                }

            } else if (dataType == DataTypeInt24) {
                if (isSigned) {
                    int32_t *d = (int32_t *)data;
                    sampleChannelData[ch].push_back(d[pos] >> 8);
                } else {
                    uint32_t *d = (uint32_t *)data;
                    sampleChannelData[ch].push_back(d[pos] >> 8);
                }

            } else if (dataType == DataTypeInt32) {
                if (isSigned) {
                    int32_t *d = (int32_t *)data;
                    sampleChannelData[ch].push_back(d[pos]);
                } else {
                    uint32_t *d = (uint32_t *)data;
                    sampleChannelData[ch].push_back(d[pos]);
                }

            } else {
                float *d = (float *)data;
                sampleChannelData[ch].push_back(d[pos]);
            }
            pos++;
        }
    }
    free(data);
    ExtAudioFileDispose(fileID);
    return sampleChannelData;
}

UInt32 getPropertySize(AudioFileID fileID, AudioFilePropertyID propertyId)
{
    UInt32 size = 0;
    OSStatus err = AudioFileGetPropertyInfo(fileID, propertyId, &size, NULL);
    if (err != noErr) {
        fprintf(stderr, "Failed to read the size for a property: '%s'\n", toStr(propertyId).c_str());
        exit(-1);
    }
    return size;
}

void storeCFValue(const void* key, const void* value, void* context)
{
    std::map<std::string, std::string> *keyValues = (std::map<std::string, std::string> *)context;
    std::string keystr = cfStringToStdString(key);
    std::string valstr = cfStringToStdString(value);
    keyValues->insert(std::make_pair(keystr, valstr));
}

void printSamples(int channels, size_t start, size_t end,
    const std::vector<std::vector<double> > &sampleChannelData, bool isFloat)
{
    for (int ch = 0; ch < channels; ch++) {
        printf("        [ ");
        size_t valcnt = 0;
        for (size_t p = start; p < end; p++) {
            if (p != start) {
                printf(",");
                if (++valcnt > 15) {
                    valcnt = 0;
                    printf("\n          ");
                } else {
                    printf(" ");
                }
            }
            if (!isFloat) {
                printf("%lld", (int64_t)sampleChannelData[ch][p]);
            } else {
                double s = sampleChannelData[ch][p];
                if (!isnan(s) && !isinf(s)) {
                    printf("%lf", s);
                } else {
                    printf("\"%lf\"", s);
                }
            }
        }
        if (ch < channels-1) {
            printf(" ],\n");
        } else {
            printf(" ]\n");
        }
    }
}

int main(int argc, const char * argv[]) {
    if (argc < 2) {
        printf("Usage: audiotoolbox-au-tester audiofile.aiff\n");
        exit(-1);
    }

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // read using AudioFile API to get marker data

    AudioFileID fileID = nil;
    OSStatus err = noErr;

    NSString *path = [NSString stringWithUTF8String: argv[1]];
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    err = AudioFileOpenURL((CFURLRef)fileURL, kAudioFileReadPermission, 0, &fileID);
    if (err != noErr) {
        fprintf(stderr, "* ERROR: can't open file: %s (%s)\n", argv[1], toStr(err).c_str());
        exit(-1);
    }

    // get file size
    SInt64 audioDataByteCount = 0;
    UInt32 fsize = getPropertySize(fileID, kAudioFilePropertyAudioDataByteCount);
    err = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataByteCount, &fsize, &audioDataByteCount);
    if (err != noErr) {
        printerr("Failed to read kAudioFilePropertyAudioDataByteCount\n");
        exit(-1);
    }

    // get file format
    SInt64 fileFormat = 0;
    UInt32 ffsize = getPropertySize(fileID, kAudioFilePropertyFileFormat);
    err = AudioFileGetProperty(fileID, kAudioFilePropertyFileFormat, &ffsize, &fileFormat);
    if (err != noErr) {
        printerr("Failed to read kAudioFilePropertyFileFormat\n");
        exit(-1);
    }
    std::string fileFormatStr = "";
    if (fileFormat == kAudioFileAIFFType) {
        fileFormatStr = "aiff";
    } else if (fileFormat == kAudioFileAIFCType) {
        fileFormatStr = "aiff-c";
    } else if (fileFormat == kAudioFileCAFType) {
        fileFormatStr = "caf";
    } else if (fileFormat == kAudioFileNextType) {
        fileFormatStr = "au";
    } else if (fileFormat == kAudioFileWAVEType) {
        fileFormatStr = "wav";
    }
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
    if (fileFormat == kAudioFileBW64Type) {
        fileFormatStr = "wav-bw64";
    } else if (fileFormat == kAudioFileRF64Type) {
        fileFormatStr = "wav-rf64";
    } else if (fileFormat == kAudioFileWave64Type) {
        fileFormatStr = "wav-w64f";
    }
#endif

    AudioStreamBasicDescription audesc;
    UInt32 dfsize = getPropertySize(fileID, kAudioFilePropertyDataFormat);
    err = AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &dfsize, &audesc);
    if (err != noErr) {
        printerr("Failed to read kAudioFilePropertyDataFormat\n");
        exit(-1);
    }
    bool isFloat = audesc.mFormatFlags & kAudioFormatFlagIsFloat;
    int bytesPerSample = audesc.mBitsPerChannel / 8;

    std::string codec;
    int bitsPerChannel = 0;
    if (audesc.mFormatID == kAudioFormatLinearPCM) {
        bitsPerChannel = (int)audesc.mBitsPerChannel;
        if (audesc.mFormatFlags & kAudioFormatFlagIsSignedInteger) {
            if (audesc.mFormatFlags & kAudioFormatFlagIsBigEndian) {
                codec = "pcm_bei";
            } else {
                codec = "pcm_lei";
            }
        } else if (audesc.mFormatFlags & kAudioFormatFlagIsFloat) {
            std::ostringstream codecStream;
            codecStream << "pcm_bef";
            codec = codecStream.str();
        } else {
            codec = "pcm_beu";
        }
    } else if (audesc.mFormatID == kAudioFormatULaw) {
        codec = "1";
    } else if (audesc.mFormatID == kAudioFormatALaw) {
        codec = "27";
    } else {
        codec.push_back((char)((audesc.mFormatID >> 24) & 255));
        codec.push_back((char)((audesc.mFormatID >> 16) & 255));
        codec.push_back((char)((audesc.mFormatID >> 8) & 255));
        codec.push_back((char)((audesc.mFormatID >> 0) & 255));
    }
    if (audesc.mFormatID == kAudioFormatULaw
        || audesc.mFormatID == kAudioFormatALaw
        || audesc.mFormatID == kAudioFormatAppleIMA4
        || audesc.mFormatID == kAudioFormatQUALCOMM
        || audesc.mFormatID == kAudioFormatQDesign
        || audesc.mFormatID == kAudioFormatQDesign2
        || audesc.mFormatID == kAudioFormatMACE3
        || audesc.mFormatID == kAudioFormatMACE6
        || audesc.mFormatID == 0x6167736d) { // "agsm"
        bitsPerChannel = 16;
    }

    int channels = audesc.mChannelsPerFrame;

    printf("{\n");
    printf("    \"format\": \"%s\",\n", fileFormatStr.c_str());
    printf("    \"sampleRate\": %g,\n", audesc.mSampleRate);
    printf("    \"channels\": %d,\n", (int)audesc.mChannelsPerFrame);
    printf("    \"codec\": \"%s\",\n", codec.c_str());
    printf("    \"sampleSize\": %d,\n", bitsPerChannel);

    AudioFileClose(fileID);

    // TODO: implement writing out values for desc if possible
    printf("    \"desc\": \"-unsupported-\",\n");

    // read using Ext API to decode compressed data

    std::vector<std::vector<double> > sampleChannelData = readExtAudioData(argv[1]);

    printf("    \"samplesPerChannel\": %lu,\n", sampleChannelData[0].size());

    const int START_SAMPLES = 300;
    printf("    \"startSamples\": [\n");
    size_t ssend = START_SAMPLES < sampleChannelData[0].size()
        ? START_SAMPLES : sampleChannelData[0].size();
    printSamples(channels, 0, ssend, sampleChannelData, isFloat);
    printf("    ],\n");

    const int END_SAMPLES = 30;
    printf("    \"endSamples\": [\n");
    size_t esstart = END_SAMPLES < sampleChannelData[0].size()
        ? sampleChannelData[0].size() - END_SAMPLES : 0;
    printSamples(channels, esstart, sampleChannelData[0].size(), sampleChannelData, isFloat);
    printf("    ]\n");

    printf("}\n");

    [pool release];

    // memory is not freed properly, we don't care!

    return 0;
}
