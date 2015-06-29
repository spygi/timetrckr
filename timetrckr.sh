#!/bin/sh

# Bashisms:
# Using [[ ]] for ifs as portability is not important, in order to protect against variable expansion.
# Enclose variables in ""
# White-space is important in ifs and variable declarations
 
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

didWeHaveLunchAlreadyOnce() {
	local COUNTER=0
	local TODAYSTIMESTAMPS=`tail -n 1 "$TIMEFILE" | awk -F "[ $TIMESEPARATOR]" '{for (i=2; i<=NF; i++) {print $i}}' | xargs -n1 date -j -f "%T" "+%s"`
	for TIMESTAMP in $TODAYSTIMESTAMPS
	do
		[[ `isItLunchTime $TIMESTAMP` = true ]] && COUNTER=$(($COUNTER + 1))
	done

	if [[ $COUNTER -gt 1 ]]
	then
		osascript -e "display notification \"Did we have lunch already? Check your $TIMEFILE\" with title \"$APPNAME\""
		sleep 4
	fi  
}

getWorkingDay() {
	echo `echo "$1" | awk '{print $1}'`
}

# Warning: OSX notifications won't work if you run the script from tmux
parseLine() {
	local LASTWORKINGDAY="$1"
	local NOTIFICATIONS="$2"
	local WRITETOFILE="$3"

	local LINE=`grep "$LASTWORKINGDAY" "$TIMEFILE"`

	# convert the line to timestamps and calculate the diff
	# Notes:
	# the space is required for [ $TIMESEPARATOR] since the date has a space
	# $0 is the full line in awk and $1 is the date, that's why we start the loop with $2
	# NR starts from 1 in awk
	local DIFF=`echo "$LINE" | awk -F "[ $TIMESEPARATOR]" '{for (i=2; i<=NF; i++) {print $i}}' | xargs -n1 date -j -f "%T" "+%s" | awk 'BEGIN{diff=0;}{if(NR%2==0){diff+=$0} else {diff-=$0}} END{print diff}'`
	
	local OUTPUT=`echo "scale=2; $DIFF/60/60" | bc` # Note that bc floors the result
	if [[ $WRITETOFILE = "true" ]]
	then  
		# do validation of the file
		if [[ $DIFF -le 0 ]]
		then
			osascript -e "display notification \"Seems you worked negative time on $LASTWORKINGDAY? Please check your $TIMEFILE\" with title \"$APPNAME\""
			exit 1
		elif [[ -f $SUMMARYFILE && -n `grep $LASTWORKINGDAY $SUMMARYFILE` ]]
		then
			osascript -e "display notification \"There exists another entry for $LASTWORKINGDAY. Please check your $SUMMARYFILE\" with title \"$APPNAME\""
			exit 1
		fi

		logger -t $APPNAME "Writing summary of $LASTWORKINGDAY in $SUMMARYFILE"
		printf "%s %s\n" $LASTWORKINGDAY $OUTPUT >> $SUMMARYFILE
	else
		echo $LASTWORKINGDAY $OUTPUT
		SUMOFHOURS=`echo "$SUMOFHOURS + $OUTPUT" | bc` # we need bc for floating point arithmetics
		[[ -z $STARTOFTIME ]] && STARTOFTIME=$LASTWORKINGDAY
		ENDOFTIME=$LASTWORKINGDAY # gets overwritten every time
	fi

	if [[ $NOTIFICATIONS = "true" ]]
	then
		local HOURS=$(( $DIFF/60/60 )) # Bash does not support float arithmetics
		local MINUTES=$(( ($DIFF/60)%60 ))
		local PRETTYTEXT=$HOURS" hours, "$MINUTES" minutes"
		osascript -e "display notification \"worked on $LASTWORKINGDAY\" with title \"$PRETTYTEXT\""
	fi
}

main() {	
	[[ ! -f $TIMEFILE ]] && logger -t $APPNAME "File $TIMEFILE not found, creating it now" && touch $TIMEFILE

	ALREADYLOGGEDINTODAY=`grep "$TODAY" "$TIMEFILE"`
	LASTSLEEPTIMEWRITTEN=`tail -n 1 "$TIMEFILE" | awk -F "$TIMESEPARATOR" '{if (NF%2 == 0) {print $NF}}'` # if NF is even
	if [[ $STATE = $WAKESTATE ]]
	then
		if [[ -z $ALREADYLOGGEDINTODAY ]]
		then
			# we start work now
			local LASTWORKINGDAY=`tail -n 1 "$TIMEFILE" | awk '{print $1}'`

			if [[ -n $LASTWORKINGDAY ]]
			then
				LASTSHUTDOWNTIMESTAMP=`tail -r /private/var/log/system.log | grep -m 1 "$SHUTDOWNPATTERN" | awk -F "$SHUTDOWNPATTERN" '{print $2}' | awk '{print $1}'`
				# an alternative way to do this would be through last shutdown | head -n 1 but too slow and the format is not suitable for date to parse
				if [[ -z $LASTSHUTDOWNTIMESTAMP ]]
				then
					osascript -e "display notification \"No shutdown time was found, please insert it manually in $TIMEFILE\" with title \"$APPNAME\""
				else
					LASTSHUTDOWNTIME=`date -j -f "%s" "$LASTSHUTDOWNTIMESTAMP" "+%T"`
					if [[ -z `tail -n 1 "$TIMEFILE" | grep "$LASTSHUTDOWNTIME"` ]]
					then
						# insert it only if it's not entered already
						logger -t $APPNAME "Writing last shutdown time to $TIMEFILE"
						sed -i '' '$ s/$/'$TIMESEPARATOR$LASTSHUTDOWNTIME'/' $TIMEFILE
					fi
				fi

				sleep 2 # give some time for the notifications
				# Create results for previous working day
				parseLine "$LASTWORKINGDAY" "true" "true"
			else
				# the script starts with a fresh FILE
				osascript -e "display notification \"$APPNAME has started recording...\" with title \"Ahoy!\""
			fi

			logger -t $APPNAME "Starting a new day"
			printf "%s %s" "$TODAY" "$TIME" >> $TIMEFILE

			exit 0
		else
			if [[ -n $LASTSLEEPTIMEWRITTEN ]]
			then
				LASTSLEEPTIMESTAMP=`date -j -f "%T" "${LASTSLEEPTIMEWRITTEN}" "+%s"`

				if [[ $(( $NOW - $LASTSLEEPTIMESTAMP )) -lt THRESHOLD ]]
				then
					# Was not big enough to be considered a lunch break
					logger -t $APPNAME "Removing last sleep time from $TIMEFILE"
					sed -i '' '$ s/'$TIMESEPARATOR$LASTSLEEPTIMEWRITTEN'//' $TIMEFILE
				else
					didWeHaveLunchAlreadyOnce

					logger -t $APPNAME "Writing new wake time to $TIMEFILE"
					sed -i '' '$ s/$/'$TIMESEPARATOR$TIME'/' $TIMEFILE

					sleep 2
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
		if [[ -z $ALREADYLOGGEDINTODAY || -n $LASTSLEEPTIMEWRITTEN ]]
		then
			# validation
			osascript -e "display notification \"State is $STATE but the entries in $TIMEFILE suggest it should be a wake event. Please check your $TIMEFILE\" with title \"$APPNAME\""
			exit 1
		elif [[ "`isItLunchTime $NOW`" = true ]]
		then
			logger -t $APPNAME "Writing sleep time to $TIMEFILE"
			sed -i '' '$ s/$/'$TIMESEPARATOR$TIME'/' $TIMEFILE # printf "%s%s" "$TIMESEPARATOR" "$TIME" >> $TIMEFILE
		else
			logger -t $APPNAME "Skipping sleep time, not into lunch limits"
		fi
	fi
}

# enter subshell so we don't pollute with variables
(
# Variables #
APPNAME="timetrckr"
TODAY=`date "+%F"` # same as +%Y-%m-%d
TIME=`date "+%T"` # same as +%H:%M:%S
NOW=`date +%s` # timestamp
SHUTDOWNPATTERN="SHUTDOWN_TIME:"
SLEEPSTATE="sleep"
WAKESTATE="wake"
SUMOFHOURS="0" # is used to add up hours for reporting

# Default settings #
# The order of settings is conf file > defaults in this file
# where ">" means more important.
# Setting the conf file is command line > default below. 
CONFFILE=$APPNAME".conf"
TIMEFILE=time.csv
SUMMARYFILE=summary.txt
THRESHOLD=$(( 10*60 )) # 10 minutes
TIMESEPARATOR=","
LUNCHSTART="11:45:00"
LUNCHSTOP="13:15:00"

# Parse command line parameters, if they exist
if [[ $# -eq 0 ]]
then
	usage
fi

# note: caller can use s and w in the same call, the latter of the two will be used
while getopts "swf:r:" opt
do
	case $opt in
	s)
		STATE=$SLEEPSTATE
		;;
	w)
		STATE=$WAKESTATE
		;;
	f)
		[[ -f $OPTARG ]] && CONFFILE=$OPTARG
		;;
	r)
		if [[ $OPTARG = "all" ]]
		then
			REPORT="all"
		else
			# yes, you can actually pass whatever you want here
			REPORT="one"
		fi
		;;
	\?)
		logger -t $APPNAME "Invalid parameter passed"
		usage
		;;
	esac
done

# Parse configuration file, this will overwrite the defaults above 
# This could be done with source .conf but it is a security risk if .conf contains crap
while read propline
do
   # ignore comment lines
   echo "$propline" | grep "^#" > /dev/null 2>&1 && continue
   # strip inline comments and set the variables
   [[ -n $propline ]] && declare `sed 's/#.*$//' <<< $propline`
done < $CONFFILE

# is it a report?
if [[ -n $REPORT && (! -f $TIMEFILE || `wc -l "$TIMEFILE" | awk '{print $1}'` = 0) ]]
then
	osascript -e "display notification \"Can't create report because $TIMEFILE does not exist or is empty.\" with title \"$APPNAME\""
	exit 1	
fi
if [[ $REPORT = "all" ]]
then
	# do not read the last line of $TIMEFILE
	# would be nice if Mac OS had the GNU head because then it would be: head -n -1
	COUNTER=0
	TOTALLINES=`wc -l "$TIMEFILE" | awk '{print $1}'`
	while read line
	do
		COUNTER=$(($COUNTER + 1))
		if [[ $COUNTER = $TOTALLINES ]]
		then
			break;
		fi
		CURRENT=`getWorkingDay "$line"`
		parseLine "$CURRENT" "false" "false"
	done < "$TIMEFILE"

	echo "Total: "$SUMOFHOURS
	osascript -e "display notification \"Worked $SUMOFHOURS hours between $STARTOFTIME and $ENDOFTIME.\" with title \"$APPNAME\""
	exit 0
elif [[ $REPORT = "one" ]]
then
	SECONDTOLASTLINE=$((`wc -l "$TIMEFILE" | awk '{print $1}'` - 1 ))
	SECONDTOLASTWORKINGDAY=`sed $SECONDTOLASTLINE'q;d' "$TIMEFILE" | awk '{print $1}'` 
	if [[ -z $SECONDTOLASTWORKINGDAY ]]
	then
		echo "Is there a previous day in the file $TIMEFILE?"
		exit 1
	fi 
	parseLine "$SECONDTOLASTWORKINGDAY" "true" "false"
	exit 0
fi

# else, check if state is given
if [[ -z $STATE ]]
then
	usage
fi

main
)
