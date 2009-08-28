#!/bin/bash
#
# Assumes directory structure generated by
# 'ruby construct_requests.rb'.
# 
# This should be similar to the following:
#
#   requests,
#           |-posts,
#           |      |-logins
#           |      `-submissions
#           |-cookies
#           `-boundaries
#
# This script uses the above structure to do some very basic load
# testing by facilitating the Apache bench (ab) tool

# Configuration
AB="/usr/sbin/ab"
AB_VERBOSITY_LEVEL="4"
LOGINS_DIR="requests/posts/logins"
SUBMISSIONS_DIR="requests/posts/submissions"
COOKIES_DIR="requests/cookies"
BOUNDARIES_DIR="requests/boundaries"
CONSTRUCT_REQUESTS="construct_requests.rb"
RUBY="/usr/bin/ruby"
LOG_DIR="load_test_results"
STDOUT_LOG="$LOG_DIR/stdout.log"
STDERR_LOG="$LOG_DIR/stderr.log"
# URI to application under test
APP_URI="http://b2270-02.red.sandbox/markus/app1"
LOGIN_URI="$APP_URI/"
SUBMISSION_URI="$APP_URI/main/submissions/update_files/1"
ASSIGNMENT_URI="$APP_URI/main/assignments/student_interface/1"
#RESULTS_URI="$APP_URI/main/assignments"

if [ $# -eq 0 ]; then
	echo "usage: run_load_test.sh student_list_file" 1>&2
	exit 1
fi

STUDENT_LIST="$1"

# Generate requests first
echo -n "Generate requests... "
$RUBY $CONSTRUCT_REQUESTS "$APP_URI" "$STUDENT_LIST"
# error checking
if [ $? -ne 0 ]; then
	echo "Failed to construct requests" 1>&2
	exit 1
fi
echo "done."

# cleanup from previous runs
if [ -e "$LOG_DIR" ]; then
	rm -rf "$LOG_DIR"
fi
mkdir -p "$LOG_DIR" # create directory for result logs

echo -n "Start load testing... "
# Loop over user-IDs and let 'ab' do its job
for user_id in $(ls "$SUBMISSIONS_DIR"); do
	# get boundary and cookie for user
	boundary=$(cat "$BOUNDARIES_DIR/${user_id}")
	cookie=$(cat "$COOKIES_DIR/${user_id}")

	# login user
	$AB -v $AB_VERBOSITY_LEVEL -n 1 -C "$cookie" -T "application/x-www-form-urlencoded" -p "$LOGINS_DIR/$user_id" "$LOGIN_URI" >> $STDOUT_LOG 2>> $STDERR_LOG
	# visit student interface for assignment 1
	$AB -v $AB_VERBOSITY_LEVEL -n 1 -C "$cookie" "$ASSIGNMENT_URI" >> $STDOUT_LOG 2>> $STDERR_LOG
	# submit files
	$AB -v $AB_VERBOSITY_LEVEL -n 1 -C "$cookie" -T "multipart/form-data; boundary=$boundary" -p "$SUBMISSIONS_DIR/$user_id" "$SUBMISSION_URI" >> $STDOUT_LOG 2>> $STDERR_LOG
done
echo "done."