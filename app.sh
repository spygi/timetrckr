#!/bin/sh
# This script will help you calculate your lunch break.
# 
# Specifically: writes wake up time in the beginning of the day.
# Sleep time if during lunch time or end-of-day times and break was big enough.
#
# Why not check also other times? 
# Because of meetings or discussions were laptop might sleep but you are still working

isItLunchOrNightTime() {
	local LUNCHSTART="11:30:00"
	local LUNCHSTOP="13:30:00"
	local NIGHTSTART="17:00:00"
	local NIGHTSTOP="23:59:59"
	if [[ $(( $1 - `date -j -f "%T" "$LUNCHSTART" "+%s"` )) -ge 0 && $(( $1 - `date -j -f "%T" "$LUNCHSTOP" "+%s"` )) -le 0 ]] 
	then
		echo true
	elif [[ $(( $1 - `date -j -f "%T" "$NIGHTSTART" "+%s"` )) -ge 0 && $(( $1 - `date -j -f "%T" "$NIGHTSTOP" "+%s"` )) -le 0 ]] 
	then 
		echo true
	fi
}

# Of course this won't work correctly with public holidays etc.
lastWorkingDay() {
    if [[ ! -z `date | grep Mon` ]]
    then
       echo `date -v-3d +%F`
    else 
		echo `date -v-1d +%F`
	fi
}

# This won't work if you run the script from tmux
showSummary() {
	local LINE=`grep "$LASTWORKINGDAY" $FILE`
	local DIFF=0
	if [[ ! -z $LINE ]]
	then
		#local NR=`cat $LINE | awk -F "$TIMESEPARATOR" '{print NR}'` # '{diff=0; cmd="date -j -f \"%T\" \"+%s\" "; for(i=0;i<NR;i++) { wake=cmd | $1; sleep=cmd } }'
		#while IFS=$TIMESEPARATOR read -ra line; do
		#	$((${line[1]} && echo "${line[1]}" | openssl dgst -sha1
		#done < inputFile
		#`osascript -e 'display notification "Lorem ipsum dolor sit amet" with title "Title"'`
	fi
}

# enter subshell so we don't pollute with variables
(  
# Settings #
FILE=time.csv
THRESHHOLD=$(( 1*60 )) # 10 minutes
TIMESEPARATOR=";" 

# Variables #
TODAY=`date "+%F"` # +%Y-%m-%d
TIME=`date "+%T"` # +%H:%M:%S
NOW=`date +%s` # timestamp
LASTWORKINGDAY=`lastWorkingDay`




[ ! -f $FILE ] && echo "File $FILE not found!\n Creating it now!" && touch $FILE
# TODO: check format of file (eg first line is of the correct format)

ALREADYLOGGEDINTODAY=`grep $TODAY $FILE`
LASTSLEEPTIME=`tail -n 1 $FILE | awk -F "$TIMESEPARATOR" '{if (NF%2 == 0) {print $NF}}'` 
if [ ! -z "$LASTSLEEPTIME" ]
then
	LASTSLEEPTIMESTAMP=`date -j -f "%T" "${LASTSLEEPTIME}" "+%s"`
fi

if [ -z "$ALREADYLOGGEDINTODAY" ]
then
	# It's a new day
	printf "%s %s" "$TODAY" "$TIME" > $FILE
	
	# run the summary for the lastWorkingDay
	if [[ `grep "$LASTWORKINGDAY"`]]
elif [[ (-z $LASTSLEEPTIME && "`isItLunchOrNightTime $NOW`" = true) ]]  
then
	echo 1 
	# We are sleeping now while lunch time
	sed -i '' '$ s/$/'$TIMESEPARATOR$TIME'/' $FILE
	# printf "%s%s" "$TIMESEPARATOR" "$TIME" >> $FILE
elif [[ $(( $NOW - $LASTSLEEPTIMESTAMP )) -lt THRESHHOLD ]]
then 
	echo 2
	# Was not big enough to be considered a (lunch or night) break
	sed -i '' '$ s/'$TIMESEPARATOR$LASTSLEEPTIME'//' $FILE
else 
	echo 3
	# we are waking up after the lunch break
	sed -i '' '$ s/$/'$TIMESEPARATOR$TIME'/' $FILE
fi
)
