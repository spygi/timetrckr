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
	# It's a new day, you look great today
	printf "%s %s" "$TODAY" "$TIME" > $FILE
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
