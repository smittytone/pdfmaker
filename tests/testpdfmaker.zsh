#!/bin/zsh

#
# testpdfmaker.zsh
#
# pdfmaker test harness
#
# @author    Tony Smith
# @copyright 2020, Tony Smith
# @version   1.0.0
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
result=$(echo -e "$result" | grep 'Error --')
if [[ -n "$result" ]]; then
    fail "Cannot access test file $test_app" "\b"
fi

# START
"$test_app" --version
echo "Running tests..."

# TEST -- create pdf, make target directory
new_test
target=test1
result=$("$test_app" -s "$image_src" -d "$target" --createdirs)

# Make sure sub-directory created
check_dir_exists "$target" $test_num

# Make sure pdf file created
check_file_exists "$target/PDF From Images.pdf" $test_num
pass

# TEST -- break pdf, make target directory
new_test
source=test1
target=test2
result=$("$test_app" -s "$source/PDF From Images.pdf" -d "$target" --createdirs -b)

# Make sure sub-directory created
check_dir_exists "$target" $test_num

# Make sure image file created
check_file_exists "$target/page 004.jpg" $test_num

rm -rf "$source"
rm -rf "$target"
pass

# TEST -- create pdf, make target by name with good extension
new_test
target=test1.pdf
result=$("$test_app" -s "$image_src" -d "$target")

# Make sure pdf file created
check_file_exists "$target" $test_num
rm "$target"
pass

# TEST -- create pdf, make target by name with bad extension
new_test
target=test1.biff
result=$("$test_app" -s "$image_src" -d "$target")

# Check for error message in output
result=$(echo -e "$result" | grep 'Error --')
if [[ -z "$result" ]]; then
    fail "Bad extension not trapped" $test_num
fi
pass

# TEST -- create pdf, make target by bad name (too long)
new_test
target=ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
result=$("$test_app" -s "$image_src" -d "$target")

# Check for error message in output
result=$(echo -e "$result" | grep 'Error --')
if [[ -z "$result" ]]; then
    fail "Bad filename not trapped" $test_num
fi
pass

# TEST -- break pdf, make target by name with bad extension
new_test
target=test1.biff
result=$("$test_app" -s "$image_src/test.pdf" -d "$target" -b)

# Check for error message in output
result=$(echo -e "$result" | grep 'Error --')
if [[ -z "$result" ]]; then
    fail "Bad target name not trapped" $test_num
fi
pass

# TEST -- break pdf, source is a directory
new_test
result=$("$test_app" -s "$image_src" -b --createdirs)

# Check for error message in output
result=$(echo -e "$result" | grep 'Error --')
if [[ -z "$result" ]]; then
    fail "Bad source name not trapped" $test_num
fi
pass

# TEST -- detect bad switch
new_test
result=$("$test_app" -s "$image_src" -d "$target" --createdirs -y)

# Check for error message in output
result=$(echo -e "$result" | grep 'Error --')
if [[ -z "$result" ]]; then
    fail "Bad switch not trapped" $test_num
fi
pass

# TEST -- detect good switch, missing value (end of line)
new_test
result=$("$test_app" -s "$image_src" -d "$target" --createdirs -c)

# Check for error message in output
result=$(echo -e "$result" | grep 'Error --')
if [[ -z "$result" ]]; then
    fail "Missing value not trapped" $test_num
fi
pass

# TEST -- detect good switch, missing value (mid line)
new_test
result=$("$test_app" -s "$image_src" -c -d "$target" --createdirs)

# Check for error message  in output
result=$(echo -e "$result" | grep 'Error --')
if [[ -z "$result" ]]; then
    fail "Missing value not trapped" $test_num
fi
pass

# TEST -- detect bad compression value (too high)
new_test
result=$("$test_app" -s "$image_src" -c 2.0 -d "$target" --createdirs)

# Check for error message in output
result=$(echo -e "$result" | grep 'out of range')
if [[ -z "$result" ]]; then
    fail "Bad value not trapped" $test_num
fi
pass

# TEST -- detect bad compression value (too low)
new_test
result=$("$test_app" -s "$image_src" -c -1.1 -d "$target" --createdirs)

# Check for error message in output
result=$(echo -e "$result" | grep 'Error --')
if [[ -z "$result" ]]; then
    fail "Bad value not trapped" $test_num
fi
pass

# TEST -- detect bad resolution value (too low)
new_test
result=$("$test_app" -s "$image_src" -r 0.7 -d "$target" --createdirs)

# Check for error message in output
result=$(echo -e "$result" | grep 'Error --')
if [[ -z "$result" ]]; then
    fail "Bad value not trapped" $test_num
fi
pass

# TEST -- detect bad resolution value (too high)
new_test
result=$("$test_app" -s "$image_src" -r 9999999 -d "$target" --createdirs)

# Check for error message in output
result=$(echo -e "$result" | grep 'Error --')
if [[ -z "$result" ]]; then
    fail "Bad value not trapped" $test_num
fi
pass

echo "ALL TESTS PASSED"