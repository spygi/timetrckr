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

# OSX notifications won't work if you run the script from tmux
showSummary() {
	local LINE=`grep "$LASTWORKINGDAY" $FILE`
	if [[ ! -z LINE ]] 
	then
		# convert the line to timestamps and calculate the diff
		# Notes:
		# the space is required for [ $TIMESEPARATOR] since the date has a space
		# $0 is the full line in awk and $1 is the date, that's why we start the loop with $2
		# NR starts from 1 in awk	
		local DIFF=`echo $LINE | awk -F "[ $TIMESEPARATOR]" '{for (i=2; i<=NF;i++) {print $i}}' | xargs -n1 date -j -f "%T" "+%s" | awk 'BEGIN{diff=0;}{if(NR%2==0){diff+=$0} else {diff-=$0}} END{print diff}'`
		# TODO if diff < 0 something's wrong
		
		local TEXT=$((DIFF/60/60))"hours "$(((DIFF%60)/60))"minutes"
		osascript -e "display notification \"worked on $LASTWORKINGDAY\" with title \"$TEXT\""
		# TODO: save it somewhere
	fi
}

# enter subshell so we don't pollute with variables
(  
# Settings #
FILE=time.csv
THRESHHOLD=$(( 10*60 )) # 10 minutes
TIMESEPARATOR=";" 
LASTWORKINGDAY=`lastWorkingDay`

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
	# It's a new day
	printf "%s %s" "$TODAY" "$TIME" >> $FILE
	
	# run the summary for the lastWorkingDay
	showSummary
elif [[ (-z $LASTSLEEPTIME && "`isItLunchOrNightTime $NOW`" = true) ]]  
then
	# We are sleeping now while lunch time
	sed -i '' '$ s/$/'$TIMESEPARATOR$TIME'/' $FILE # printf "%s%s" "$TIMESEPARATOR" "$TIME" >> $FILE
elif [[ ! -z $LASTSLEEPTIME ]]
then 
	# We are waking up again
	if [[ $(( $NOW - $LASTSLEEPTIMESTAMP )) -lt THRESHHOLD ]]
	then
		# Was not big enough to be considered a (lunch or night) break
		sed -i '' '$ s/'$TIMESEPARATOR$LASTSLEEPTIME'//' $FILE
	else 
		# write a new wake time
		sed -i '' '$ s/$/'$TIMESEPARATOR$TIME'/' $FILE
	fi
fi
)
