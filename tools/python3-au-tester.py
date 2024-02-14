#!/usr/bin/python3

# Tests how the python3 sunau package reads AU files. Requires python version less than 3.13.

import sunau
import sys
try:
    from tinytag import TinyTag
except ImportError:
    pass

try:
    afile = sunau.open(sys.argv[1], "r")
except Exception as e:
    print("Exception for '" + sys.argv[1] + "':", e, file=sys.stderr)
    exit(-1)

chcount = afile.getnchannels()
sampwidth = afile.getsampwidth()
samplerate = afile.getframerate()
comptype = afile.getcomptype()
compname = afile.getcompname()
markers = afile.getmarkers()
strframes = afile.readframes(1000000)
frames = []
for i in range(0, round(len(strframes)/sampwidth)):
    if sampwidth == 1:
        s = strframes[i]
        if s > 127:
            s -= 256
        frames.append(s)
    elif sampwidth == 2:
        if comptype == "alaw" or comptype == "ulaw" or comptype == "ALAW" or comptype == "ULAW":
            try:
                s = strframes[i*2+1] * 256 + strframes[i*2]
            except:
                break
        else:
            s = strframes[i*2] * 256 + strframes[i*2+1]
        if s > 32767:
            s -= 65536
        frames.append(s)
    elif sampwidth == 3:
        s = strframes[i*3] * 65536 + strframes[i*3+1] * 256 + strframes[i*3+2]
        if s > 8388607:
            s -= 16777216
        frames.append(s)
    elif sampwidth == 4:
        s = strframes[i*4] * 16777216 + strframes[i*4+1] * 65536 + strframes[i*4+2] * 256 + strframes[i*4+3]
        if s > 2147483647:
            s -= 4294967296
        frames.append(s)
afile.close()

codec = comptype.lower()
if codec == "none":
    codec = "pcm_bei"
elif codec == "ulaw":
    codec = "1"
elif codec == "alaw":
    codec = "27"

print(f"{{")
print(f"    \"format\": \"au\",")
print(f"    \"sampleRate\": {samplerate},")
print(f"    \"channels\": {chcount},")
print(f"    \"codec\": \"{codec}\",")
print(f"    \"sampleSize\": {sampwidth*8},")
print(f"    \"desc\": \"-unsupported-\",")

samples_per_channel = int(len(frames)/chcount)
print(f"    \"samplesPerChannel\": {samples_per_channel},")

def print_samples(chcount, start, end, frames):
    for ch in range(0, chcount):
        print("        [ ", end='')
        valcnt = 0
        for pos in range(start, end):
            if pos != start:
                print(",", end='')
                valcnt += 1
                if (valcnt > 15):
                    valcnt = 0
                    print()
                    print("          ", end='')
                else:
                    print(" ", end='')
            print(frames[pos * chcount + ch], end='')
        if ch < chcount-1:
            print(" ],")
        else:
            print(" ]")

print(f"    \"startSamples\": [")
print_samples(chcount, 0, min(round(samples_per_channel), 300), frames)
print(f"    ],")

print(f"    \"endSamples\": [")
estart = samples_per_channel - 30
if estart < 0:
    estart = 0
print_samples(chcount, estart, samples_per_channel, frames)
print(f"    ]")

print(f"}}")
