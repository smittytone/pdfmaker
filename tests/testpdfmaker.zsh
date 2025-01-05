#!/bin/zsh

#
# testpdfmaker.zsh
#
# pdfmaker test harness
#
# @author    Tony Smith
# @copyright 2025, Tony Smith
# @version   1.0.1
# @license   MIT
#

test_app="$1"
image_src="$(pwd)/source"
test_num=0

fail() {
    echo "\rTEST $2 FAILED -- $1"
    exit  1
}

pass() {
    echo " PASSED"
}

new_test() {
    ((test_num+=1))
    echo -n "TEST $test_num..."
}

check_dir_exists() {
    if [[ ! -e "$1" ]]; then
        fail "Sub-directory $1 not created" $2
    fi
}

check_dir_not_exists() {
    if [[ -e "$1" ]]; then
        fail "Sub-directory $1 created" $2
    fi
}

check_file_exists() {
    if [[ ! -e "$1" ]]; then
        fail "File $1 not created" $2
    fi
}

check_file_not_exists() {
    if [[ -e "$1" ]]; then
        fail "File $1 created" $2
    fi
}

# Check test app exists
result=$(which "$test_app")
result=$(echo -e "$result" | grep 'not found')
if [[ -n "$result" ]]; then
    fail "Cannot access test file $test_app" "\b"
fi

# START
"$test_app" --version
echo "Running tests..."

# TEST -- create pdf, make target directory
new_test
targetfile=test1
result=$("$test_app" -s "$image_src" -d "$targetfile" --createdirs 2>&1)

# Make sure sub-directory created
check_dir_exists "$targetfile" $test_num

# Make sure pdf file created
check_file_exists "$targetfile/PDF From Images via pdfmaker.pdf" $test_num
pass

# TEST -- break pdf, make target directory
new_test
sourcefile=test1
targetfile=test2
result=$("$test_app" -s "$sourcefile/PDF From Images via pdfmaker.pdf" -d "$targetfile" --createdirs -b 2>&1)

# Make sure sub-directory created
check_dir_exists "$targetfile" $test_num

# Make sure image file created
check_file_exists "$targetfile/page 004.jpg" $test_num

rm -rf "$sourcefile"
rm -rf "$targetfile"
pass

# TEST -- create pdf, make target by name with good extension
new_test
targetfile=test1.pdf
result=$("$test_app" -s "$image_src" -d "$targetfile" 2>&1)

# Make sure pdf file created
check_file_exists "$targetfile" $test_num
rm "$targetfile"
pass

# TEST -- create pdf, make target by name with bad extension
new_test
targetfile=test1.biff
result=$("$test_app" -s "$image_src" -d "$targetfile" 2>&1)

# Check for error message in output
result=$(echo -e "$result" | grep 'does not reference')
if [[ -z "$result" ]]; then
    fail "Bad extension not trapped" $test_num
fi
pass

# TEST -- create pdf, make target by bad name (too long)
new_test
targetfile=ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd.pdf
result=$("$test_app" -s "$image_src" -d "$targetfile" 2>&1)

# Check for error message in output
result=$(echo -e "$result" | grep 'is too long')
if [[ -z "$result" ]]; then
    fail "Bad filename not trapped" $test_num
fi
pass

# TEST -- break pdf, make target by name with bad extension
new_test
targetfile=test1.biff
result=$("$test_app" -s "$image_src/test.pdf" -d "$targetfile" -b 2>&1)

# Check for error message in output
result=$(echo -e "$result" | grep 'is not a directory')
if [[ -z "$result" ]]; then
    fail "Bad target name not trapped" $test_num
fi
pass

# TEST -- break pdf, source is a directory
new_test
result=$("$test_app" -s "$image_src" -b --createdirs 2>&1)

# Check for error message in output
result=$(echo -e "$result" | grep 'is a directory')
if [[ -z "$result" ]]; then
    fail "Bad source name not trapped" $test_num
fi
pass

# TEST -- detect bad switch
new_test
result=$("$test_app" -s "$image_src" -d "$targetfile" --createdirs -y 2>&1)

# Check for error message in output
result=$(echo -e "$result" | grep 'Unknown argument')
if [[ -z "$result" ]]; then
    fail "Bad switch not trapped" $test_num
fi
pass

# TEST -- detect good switch, missing value (end of line)
new_test
result=$("$test_app" -s "$image_src" -d "$targetfile" --createdirs -c 2>&1)

# Check for error message in output
result=$(echo -e "$result" | grep 'Missing value for')
if [[ -z "$result" ]]; then
    fail "Missing value not trapped" $test_num
fi
pass

# TEST -- detect good switch, missing value (mid line)
new_test
result=$("$test_app" -s "$image_src" -c -d "$targetfile" --createdirs 2>&1)

# Check for error message  in output
result=$(echo -e "$result" | grep 'Missing value for')
if [[ -z "$result" ]]; then
    fail "Missing value not trapped" $test_num
fi
pass

# TEST -- detect bad compression value (too high)
new_test
result=$("$test_app" -s "$image_src" -c 2.0 -d "$targetfile" --createdirs 2>&1)

# Check for error message in output
result=$(echo -e "$result" | grep 'out of range')
if [[ -z "$result" ]]; then
    fail "Bad value not trapped" $test_num
fi
pass

# TEST -- detect bad compression value (too low)
new_test
result=$("$test_app" -s "$image_src" -c -1.1 -d "$targetfile" --createdirs 2>&1)

# Check for error message in output
result=$(echo -e "$result" | grep 'Missing value for')
if [[ -z "$result" ]]; then
    fail "*Bad value not trapped" $test_num
fi
pass

# TEST -- detect bad resolution value (too low)
new_test
result=$("$test_app" -s "$image_src" -r 0.7 -d "$targetfile" --createdirs 2>&1)

# Check for error message in output
result=$(echo -e "$result" | grep 'out of range')
if [[ -z "$result" ]]; then
    fail "Bad value not trapped" $test_num
fi
pass

# TEST -- detect bad resolution value (too high)
new_test
result=$("$test_app" -s "$image_src" -r 9999999 -d "$targetfile" --createdirs 2>&1)

# Check for error message in output
result=$(echo -e "$result" | grep 'out of range')
if [[ -z "$result" ]]; then
    fail "Bad value not trapped" $test_num
fi
pass

# TEST -- detect unsupported file type
new_test
sourcefile="source/Out of this World.gif"
targetfile=test3
result=$("$test_app" -s "$sourcefile" -d "$targetfile" --createdirs 2>&1)

result=$(echo -e "$result" | grep 'is not a supported image type')
if [[ -z "$result" ]]; then
    fail "Unsupported file warning not issued" $test_num
fi

# Check for error message in output
check_file_not_exists "$targetfile/PDF From Images via pdfmaker.pdf" $test_num
pass

echo "ALL TESTS PASSED"
