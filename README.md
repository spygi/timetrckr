This script will help you calculate your working hours by recording boot, shutdown and time spent during lunch. I know, it should probably be named _lunchtime_ or something but _timetrckr_ sounds cooler (and more ambitious too :) )


## Installation
1. Clone this project.

1. Install sleepwatcher: ```brew install sleepwatcher``` (tested with version 2.2)

1. Set up launchd: ```cp de.bernhard-baehr.sleepwatcher-20compatibility-localuser.plist timetrckr.plist ~/Library/LaunchAgents/``` Change the _WorkingDirectory_ in both of the .plists to point to the location where you cloned the repo.

Done. Next time you boot, the script will start recording time. If you want to start it now: ```launchctl load ~/Library/LaunchAgents/timetrckr.plist``` and ```sleepwatcher.plist```(launchctl does not work inside tmux)


## Reporting
For every new day the script writes the number of hours you worked in the previous day. You can produce the report anew also manually by running ```./timetrckr.sh -r all``` to get the summary for all days recorded, or ```-r one``` for the last day only. The outcome will be written in standard output (you can always redirect it to a file) and the overall hours will be shown with a Growl-like notification (notifications don't work from inside tmux).


## Configuration
Have a look at ```timetrckr.conf``` for which parameters you can customize. If you want to use a different .conf file, specify it in the _ProgramArguments_ of the two .plists with ```-f```: ```./timetrckr.sh -w -f <path_to_conf_file>``` (and similar for ```-s```).


## <a name="howDoesItWork"></a> How does it work?
The excellent [Sleepwatcher daemon](http://www.bernhard-baehr.de/) catches sleep and wake events (could be extended to catch also login events but me no speak no C). Timetrckr.plist catches login events. Shutdown events are caught by the script itself (on the beginning of a new day). This is done by grepping the logs because shutdowns are not propagated properly to launchd daemons (see [Issue#5](http://github.com/spygi/timetrckr/issues/5)).


## FAQ
### Why is it so dumb? Do I really have to set up a range of lunch hours?
Well, basically because I don't need something more sophisticated (or didn't figure a simple enough solution to detect if you are in a meeting or just taking a break). The script will work well enough for computer based, desk jobs with standard working hours (or should I say standard lunch hours?).

### What if I take an additional break, outside of lunch times?
This won't be recorded. You can still temper with the output of the file..it is just text after all. Just make sure you keep the same format (separator and time formats) and you should be fine. Note that if you change the ```time.csv``` file you should re-generate the summary using the ```-r``` argument.

### Can I sync with other devices?
Sure, just configure the output to be in a Dropbox synced folder.

### Do I need both .plists?
Yes, see [How does it work](#-how-does-it-work) as well. Instead of the ```timetrck.plist``` you could create an Application in Automator with a Run Shell script action which contains ```./timetrckr.sh```, save it and make it a Login Item in System Preferences.

### I don't see anything.
Make sure the Sleepwatcher (or timetrckr) daemons are loaded eg: ```launchctl list | grep sleepwatcher```

### I see the daemons running but no output.
Make sure the script is executable: ```chmod 755 path_to_timetrckr.sh```

### I still don't see anything.
Open the Console.app, maybe it helps you. Otherwise have a look at the code, it's pretty simple.
