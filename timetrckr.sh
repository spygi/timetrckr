#!/bin/sh

# This script will help you calculate your lunch break.
# 
# Specifically: writes wake up time in the beginning of the day.
# Sleep time if during lunch time and break was big enough.
#
# Why not check also other times? 
# Because of meetings or discussions were laptop might sleep but you are still working

usage() {
	logger -t $APPNAME "Usage: -s|-w, optional -f <conf.file> or -r [all] for reporting"
	exit 1
}

isItLunchTime() {
	if [[ $(( $1 - `date -j -f "%T" "$LUNCHSTART" "+%s"` )) -ge 0 && $(( $1 - `date -j -f "%T" "$LUNCHSTOP" "+%s"` )) -le 0 ]] 
	then
		echo true
	fi
}

getLastWorkingDay() {
	echo `tail -n 1 $FILE | awk '{print $1}'`
}

getWorkingDay() {
	echo `echo "$1" | awk '{print $1}'`
}

# Warning: OSX notifications won't work if you run the script from tmux
showSummary() {
	local LASTWORKINGDAY=$1
	local NOTIFICATIONS=$2
	local WRITETOFILE=$3

	local LINE=`grep "$LASTWORKINGDAY" $FILE`

	# convert the line to timestamps and calculate the diff
	# Notes:
	# the space is required for [ $TIMESEPARATOR] since the date has a space
	# $0 is the full line in awk and $1 is the date, that's why we start the loop with $2
	# NR starts from 1 in awk	
	local DIFF=`echo $LINE | awk -F "[ $TIMESEPARATOR]" '{for (i=2; i<=NF;i++) {print $i}}' | xargs -n1 date -j -f "%T" "+%s" | awk 'BEGIN{diff=0;}{if(NR%2==0){diff+=$0} else {diff-=$0}} END{print diff}'`

	if [[ $DIFF -le 0 ]]
	then 
		osascript -e "display notification \"Seems you worked negative time on $LASTWORKINGDAY? Please check your $FILE\" with title \"$APPNAME\""
		exit 1;
	elif [[ -f $OUTPUTFILE && ! -z `grep $LASTWORKINGDAY $OUTPUTFILE` ]]  
	then
		osascript -e "display notification \"There exists another entry for $LASTWORKINGDAY. Please check your $OUTPUTFILE\" with title \"$APPNAME\""
		exit 1;
	fi

	if [[ $NOTIFICATIONS = "true" ]]
	then 
		local HOURS=$(( $DIFF/60/60 )) # Bash does not support float arithmetics
		local MINUTES=$(( ($DIFF/60)%60 ))
		local PRETTYTEXT=$HOURS" hours, "$MINUTES" minutes"
		osascript -e "display notification \"worked on $LASTWORKINGDAY\" with title \"$PRETTYTEXT\""
	fi

	# Here we need additional precision (2 digits)
	# Note that bc floors the result
	local OUTPUT=`echo "scale=2; $DIFF/60/60" | bc` 
	if [[ $WRITETOFILE = "true" ]]
	then 
		logger -t $APPNAME "Writing summary of $LASTWORKINGDAY in $OUTPUTFILE" 
		printf "%s %s\n" $LASTWORKINGDAY $OUTPUT >> $OUTPUTFILE 
	else
		echo $LASTWORKINGDAY $OUTPUT
	fi
}

main() {
	[ ! -f $FILE ] && logger -t $APPNAME "File $FILE not found, creating it now" && touch $FILE

	ALREADYLOGGEDINTODAY=`grep $TODAY $FILE`
	LASTSLEEPTIME=`tail -n 1 $FILE | awk -F "$TIMESEPARATOR" '{if (NF%2 == 0) {print $NF}}'` # NF is even
	if [[ "$STATE" = "$WAKESTATE" ]]
	then 
		if [[ -z "$ALREADYLOGGEDINTODAY" ]] 
		then 
			# we start work now
			local LASTWORKINGDAY=`getLastWorkingDay` 
			
			if [[ ! -z $LASTWORKINGDAY ]]
			then
				LASTSHUTDOWNTIMESTAMP=`tail -r /private/var/log/system.log | grep -m 1 $SHUTDOWNPATTERN | awk -F "$SHUTDOWNPATTERN" '{print $2}' | awk '{print $1}'`
				# an alternative way to do this would be through last shutdown | head -n 1 but too slow and the format is not suitable for date to parse
				if [ -z $LASTSHUTDOWNTIMESTAMP ]
				then 
					osascript -e "display notification \"No shutdown time was found, please insert it manually in $FILE\" with title \"$APPNAME\""
				else 
					LASTSHUTDOWNTIME=`date -j -f "%s" $LASTSHUTDOWNTIMESTAMP "+%T"` 
					if [[ -z `tail -n 1 $FILE | grep $LASTSHUTDOWNTIME` ]] 
					then
						# insert it only if it's not entered already
						logger -t $APPNAME "Writing last shutdown time to $FILE"
						sed -i '' '$ s/$/'$TIMESEPARATOR$LASTSHUTDOWNTIME'/' $FILE
					fi
				fi

				sleep 2 # give some time for the notifications
				# Create results for previous working day	
				showSummary $LASTWORKINGDAY "true" "false"
			else
				# the script starts with a fresh FILE
				osascript -e "display notification \"$APPNAME has started recording...\" with title \"Ahoy!\""
			fi

			logger -t $APPNAME "Starting a new day"
			printf "%s %s" "$TODAY" "$TIME" >> $FILE

			exit 0;
		else 
			if [ ! -z "$LASTSLEEPTIME" ]
			then
				LASTSLEEPTIMESTAMP=`date -j -f "%T" "${LASTSLEEPTIME}" "+%s"`
				
				if [[ $(( $NOW - $LASTSLEEPTIMESTAMP )) -lt THRESHOLD ]]
				then
					# Was not big enough to be considered a lunch break
					logger -t $APPNAME "Removing last sleep time from $FILE"
					sed -i '' '$ s/'$TIMESEPARATOR$LASTSLEEPTIME'//' $FILE
				else 
					logger -t $APPNAME "Writing new wake time to $FILE"
					sed -i '' '$ s/$/'$TIMESEPARATOR$TIME'/' $FILE
				
					sleep 2;	
					osascript -e "display notification \"Resuming recording...\" with title \"$APPNAME\""
				fi
			else 
				# This is *not* a validation error
				# It can happen eg if a sleep outside of lunch time happens (for a meeting) 
				# and then we wake up during lunch: the sleep time is skipped as it should.
				logger -t $APPNAME "Seems like the previous sleep was not reported (was it outside lunch times?), doing nothing" 
			fi
		fi
	else 
		# we are sleeping
		if [[ -z $ALREADYLOGGEDINTODAY || ! -z "$LASTSLEEPTIME" ]] 
		then
			# validation
			osascript -e "display notification \"State is $STATE but the entries in $FILE suggest it should be a wake event. Please check your $FILE\" with title \"$APPNAME\""
			exit 1;
		elif [[ "`isItLunchTime $NOW`" = true ]]
		then
			logger -t $APPNAME "Writing sleep time to $FILE"
			sed -i '' '$ s/$/'$TIMESEPARATOR$TIME'/' $FILE # printf "%s%s" "$TIMESEPARATOR" "$TIME" >> $FILE
		else
			logger -t $APPNAME "Skipping sleep time, not into lunch limits"
		fi
	fi
}

# enter subshell so we don't pollute with variables
( 
# Variables #
APPNAME="timetrckr"
TODAY=`date "+%F"` # +%Y-%m-%d
TIME=`date "+%T"` # +%H:%M:%S
NOW=`date +%s` # timestamp
SHUTDOWNPATTERN="SHUTDOWN_TIME:"
SLEEPSTATE="sleep"
WAKESTATE="wake"

# Default settings #
CONFFILE=$APPNAME".conf" 
FILE=time.csv
OUTPUTFILE=summary.csv
THRESHOLD=$(( 10*60 )) # 10 minutes
TIMESEPARATOR=";" 
LUNCHSTART="11:30:00"
LUNCHSTOP="13:30:00"

# Parse command line parameters #
# if they exist
if [ "$#" -eq 0 ]
then
	usage
fi

# f requires an argument, the file for configuration
# note: caller can use both s and w, the latter will be used
while getopts "swf:r:" opt
do
	case $opt in
	s)
		logger -t $APPNAME "s selected"
		STATE=$SLEEPSTATE
		;;
	w)
		logger -t $APPNAME "w selected"
		STATE=$WAKESTATE
		;;
	f)
		logger -t $APPNAME "f selected"
		[ -f $OPTARG ] && CONFFILE=$OPTARG
		;;
	r)
		logger -t $APPNAME "r selected"
		if [[ $OPTARG = "all" ]]
		then
			REPORT="all"
		else
			REPORT="one"
		fi
		;;
	\?)
		logger -t $APPNAME "Invalid arg"
		usage
		;;
	esac
done

if [[ $REPORT = "all" ]]
then
	# TODO handle if summary file exists already
	while read line
	do
		CURRENT=`getWorkingDay $line`
		showSummary $CURRENT "false" "true" 
	done < $FILE # this loop works only if the file has at least 2 lines...  
	# TODO echo the final number 
	exit 0
elif [[ $REPORT = "one" ]] 
then
	showSummary `getLastWorkingDay` "true" "false" 
	exit 0
fi

# check if mandatory arguments were given
if [[ -z $STATE ]]
then
	usage 
fi

# Parse configuration file, this will overwrite the defaults above #
while read propline 
do 
   # ignore comment lines
   echo "$propline" | grep "^#" > /dev/null 2>&1 && continue
   # strip inline comments and set the variables 
   [ ! -z "$propline" ] && declare `sed 's/#.*$//' <<< $propline` 
done < $CONFFILE

main
)

