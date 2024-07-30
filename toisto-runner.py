# Toisto Runner for Toisto test suites
#
# Calls command for each test file under the tests folder and compares its
# output to the test file's json file.
#
# Compatible with python 2.6 and python 3.
#

import json
import sys
import os
import subprocess

build_version = "0.24.730.0"

def run_command(command, filename, verbose):
    cmd = " ".join(command) + " " + filename
    if verbose > 1:
        print("Command: "+cmd)
    ch = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    res = ch.communicate()
    return (res[0], res[1], ch.returncode)

def check_key(testresult, testref, key):
    if not key in testresult:
        return " - value missing: " + str(key)
    if not key in testref:
        return " - BAD REFERENCE FILE: value missing: " + str(key)
    return ""

def compare_value(resval, refval, key):
    if type(refval) is list:
        if len(resval) != len(refval):
            return " - values differ for \"" + key + "\", got: '" + str(resval) + "', expected: '" +str(refval)+"'"
        for i in range(0, len(refval)):
            err = compare_value(resval[i], refval[i], key)
            if err != "":
                return err
        return ""

    if type(refval) is dict:
        for k in refval.keys():
            err = compare_field(resval, refval, k)
            if err != "":
                return err
        return ""

    if ((type(refval) is str and resval != refval) or
        (type(refval) is int and float(resval) != float(refval)) or
        (type(refval) is float and float(resval) != float(refval))):
        return " - values differ for \"" + key + "\", got: '" + str(resval) + "', expected: '" +str(refval)+"'"
    return ""

def compare_field(testresult, testref, key):
    if not key in testref:
        return ""
    if not key in testresult:
        return " - value missing: " + str(key)
    if testresult[key] == "-unsupported-":
        return " - unsupported: " + str(key)
    resval = testresult[key]
    refval = testref[key]
    return compare_value(resval, refval, key)

def compare_samples(testref, testresult, fieldname, tolerance, errors):
    for chinx, chsamples in enumerate(testref[fieldname]):
        for inx, sample in enumerate(chsamples):
            if chinx < len(testresult[fieldname]) and inx < len(testresult[fieldname][chinx]):
                tres = testresult[fieldname][chinx][inx]
            else:
                tres = "none"
            if isinstance(tres, (int, float)) and isinstance(sample, (int, float)):
                # allow some variation in values, because of possible rounding errors
                if tres < sample-tolerance or tres > sample+tolerance:
                    errors.append(" - values differ for \"" + fieldname + "\", channel " + str(chinx) + ", index " + str(inx) + ", got: " + str(tres) + ", expected: " + str(sample))
                    return
            elif tres != sample:
                errors.append(" - values differ for \"" + fieldname + "\", channel " + str(chinx) + ", index " + str(inx) + ", got: " + str(tres) + ", expected: " + str(sample))
                return

def print_verbose(verbose, msg):
    if verbose > 0:
        try:
            print(msg)
        except UnicodeEncodeError:
            print(msg.encode("utf-8", "ignore"))

def red(text):
    if args["colors"]:
        return '\033[31m' + text + '\033[0m'
    return text

def red_if_non_zero(count, text):
    if args["colors"] and count > 0:
        return '\033[31m' + str(count) + text + '\033[0m'
    return str(count) + text

# main

args = {
    "verbose": 0,
    "override_folder": "",
    "override_list": {},
    "command": [],
    "colors": False
}
findex = 1
while findex < len(sys.argv):
    if sys.argv[findex] == "--version":
        print(build_version)
        exit(0)
    if sys.argv[findex].startswith("-v"):
        args["verbose"] = sys.argv[findex].count("v")
        findex += 1
    if sys.argv[findex].startswith("-c"):
        args["colors"] = True
        findex += 1
    elif sys.argv[findex] == "--override-folder":
        args["override_folder"] = sys.argv[findex+1]
        findex += 2
    elif sys.argv[findex] == "--override-list":
        try:
            with open(sys.argv[findex+1], 'r') as f:
                args["override_list"] = json.loads(f.read())
        except:
            print("ERROR: INVALID OVERRIDE LIST:", sys.argv[findex+1])
            raise
        findex += 2
    elif sys.argv[findex] == "-i":
        args["input_folder"] = sys.argv[findex+1]
        findex += 2
    else:
        while findex < len(sys.argv):
            args["command"].append(sys.argv[findex])
            findex += 1

if len(args["command"]) == 0:
    print("Usage: toisto-runner.py [-v] [-vv] [-i input_folder] [--override-folder override_folder] [--override-list override-list.json] command...")
    print(" -v                  verbose mode")
    print(" -vv                 more verbose mode")
    print(" -i                  input folder (default tests)")
    print(" -c                  enable color mode")
    print(" --override-folder   override folder for JSON files (default none)")
    print(" --override-list     override list file (default none)")
    print(" command...          command and its args to run")
    exit(-1)

if args["colors"]:
    # hack to enable colors on windows 10 until https://github.com/python/cpython/issues/84315
    os.system("")

print("Testing command: " + args["command"][0])

# convert command to Windows or Unix format (to use forward or backward slashes)
args["command"][0] = os.path.join(*args["command"][0].split("/"))

if not os.path.exists(args["command"][0]) and not os.path.exists(args["command"][0]+".exe"):
    print("ERROR: Command does not exist!")
    exit(-1)

# get files
filenames = []
folder = "tests/"
if "input_folder" in args:
    folder = args["input_folder"]
    if not folder.endswith("/"):
        folder += "/"

for tf in os.listdir(folder):
    if tf.startswith("."):
        continue
    if os.path.isdir(folder+tf):
        filenames += [folder+tf+"/"+f for f in os.listdir(folder+tf)]
    else:
        filenames.append(folder+tf)
        continue
filenames.sort()

totalcount = 0
count = {
    "fail": 0,
    "ignore": 0
}
needs_linefeed_before_ok = False

# process json files
for test_filename in filenames:
    if test_filename.endswith(".json") or os.path.split(test_filename)[1].startswith("."):
        continue

    totalcount += 1
    json_filename = os.path.splitext(test_filename)[0] + ".json"
    if test_filename == "":
        print("ERROR: test file for " + json_filename + " not found")
        continue

    # read ref file or override ref file
    override_json_filename = args["override_folder"]+"/"+json_filename
    if os.path.exists(override_json_filename):
        f = open(override_json_filename, "rb")
    else:
        f = open(json_filename, "rb")
    refcontents = f.read().decode("utf-8")
    try:
        testref = json.loads(refcontents)
    except:
        print("ERROR: INVALID JSON IN REF FILE:", json_filename)
        print(refcontents)
        raise

    if test_filename in args["override_list"]:
        testref.update(args["override_list"][test_filename])

    ignored_test = False
    if "result" in testref and testref["result"] == "ignore":
        ignored_test = True

    # execute command for test file
    (res, cmderror, exitstatus) = run_command(args["command"], test_filename, args["verbose"])
    if exitstatus != 0:
        if ignored_test:
            print_verbose(args["verbose"], "\n(FAIL): "+test_filename)
            count[testref["result"]] += 1
        else:
            print_verbose(args["verbose"], red("\nFAIL  : ")+test_filename)
            count["fail"] += 1
        if len(cmderror) > 0:
            print_verbose(args["verbose"], cmderror.decode("utf-8").strip())
        print_verbose(args["verbose"], " - process returned non-zero exit status: "+str(exitstatus))
        needs_linefeed_before_ok = True
        continue

    # parse json
    errors = []
    try:
        testresult = json.loads(res)
    except Exception as e:
        cmdres_str = res.decode("utf-8")
        errors.append("* ERROR: Got invalid JSON: " + str(e) + ":\n" + cmdres_str + "\n")
        testresult = { "format": "-unsupported-" }

    # compare results

    for field in testref:
        if field == "testinfo" or field == "result" or field == "tolerance" \
            or field == "startSamples" or field == "endSamples":
            continue
        errors.append(compare_field(testresult, testref, field))

    tolerance = 0
    if "tolerance" in testref:
        tolerance = float(testref["tolerance"])

    if "startSamples" in testref:
        if not "startSamples" in testresult:
            errors.append(" - value missing: startSamples")
        elif testresult["startSamples"] != "-unsupported-":
            compare_samples(testref, testresult, "startSamples", tolerance, errors)
        else:
            errors.append(" - unsupported: startSamples");

    if "endSamples" in testref:
        if not "endSamples" in testresult:
            errors.append(" - value missing: endSamples")
        elif testresult["endSamples"] != "-unsupported-":
            compare_samples(testref, testresult, "endSamples", tolerance, errors)
        else:
            errors.append(" - unsupported: endSamples");

    # unsupported error messages are not failures
    failed = False
    for e in errors:
        if e != "" and not e.startswith(" - unsupported"):
            failed = True
            break

    # print result for a test file

    if failed:
        if ignored_test:
            print_verbose(args["verbose"], "\n(FAIL): "+test_filename)
            count[testref["result"]] += 1
        else:
            print_verbose(args["verbose"], red("\nFAIL  : ")+test_filename)
            count["fail"] += 1
        needs_linefeed_before_ok = True
    else:
        if needs_linefeed_before_ok:
            print_verbose(args["verbose"], "")
        needs_linefeed_before_ok = False
        if ignored_test:
            print_verbose(args["verbose"], "(OK)  : "+test_filename)
            count[testref["result"]] += 1
        else:
            print_verbose(args["verbose"], "OK    : "+test_filename)

    if len(cmderror) > 0:
        print(cmderror.decode("utf-8").strip())
        needs_linefeed_before_ok = True

    non_blank_errors = [e for e in errors if e != ""]
    errorstr = "\n".join(non_blank_errors)
    if errorstr != "":
        print_verbose(args["verbose"], errorstr)
        needs_linefeed_before_ok = True

# print totals

print_verbose(args["verbose"], "")
print("Total " + str(totalcount) + ": " +
    str(totalcount-count["fail"]-count["ignore"]) +  " passed, " +
    red_if_non_zero(count["fail"], " failed") + ", " + str(count["ignore"]) +  " ignored.")

if count["fail"] > 0:
    exit(1)
