This script will help you calculate your working hours by recording boot, shutdown and time spent during lunch. I know, it should probably be named lunchtime or something but timetrckr sounds cooler (and more ambitious too :) )


## Installation
1. Install sleepwatcher: ```brew install sleepwatcher```

1. Set up launchd: ```cp de.bernhard-baehr.sleepwatcher-20compatibility-localuser.plist timetrckr.plist ~/Library/LaunchAgents/```  

Done. Next time you boot, the script will start recording time. If you want to start it now (not recommended): ```launchctl load ~/Library/LaunchAgents/*``` (warning: launchctl does not work inside tmux)


## Reporting
Just run ```./timetrckr.sh -r all``` for all days, or ```one``` for the last day. For all days the outcome will be in summary.csv (unless customized) and the overall hours will be echoed in standard output. For one day you will see a Growl-like notification (unless you run it inside tmux) and the number of hours will be printed in standard output.


## Configuration
Have a look at timetrckr.conf, you can customize some parameters. If you want to use different conf file, change the .plists to -f <path_to_conf_file>


## How does it work?
The excelent Sleepwatcher (link) catches sleep and wake events. Timetrckr.plist catches login events. Shutdown events are caught by the script itself (on the beggining of a new day). The reason for this separation is that Sleepwatcher is not programmed to catch other events (and I didn't feel like learning C to extend it). Shutdowns are not propagated properly to launchd daemons (see #3) so for them I grep the logs.


## FAQ
### Why is it so dumb? Do I really have to set up a range of lunch hours?
Well, basically because I don't need something additional (or didn't figure a simple enough solution to detect if you are in a meeting or just taking a break). The script will work well enough for static, desk jobs with standard working hours (or should I say standard lunch hours?).

### Do I need both .plists?
Yes, see [#howDoesItWork] section as well. Instead of the timetrck.plist you could create an Application in Automator with a Run Shell script action which contains ``` source path_to_script```, save it and make it a Login Item in System Preferences.

### Can I sync with other devices?
Sure, just configure the output to be in a Dropbox synced folder.

### I don't see anything.
Make sure the Sleepwatcher (or timetrckr) daemons are loaded: ```launchctl list | grep sleepwatcher```

### I see the daemons running but no output.
Make sure the script is executable: ```chmod 755 path_to_timetrckr.sh```

### I still don't see anything.
Open the Console.app, maybe it helps you. Otherwise have a look at the code, it's pretty simple.

### What if I take an additional break, outside of lunch times?
You can still temper with the output of the file..it is just text after all. Just make sure you keep the same format (separator and time formats) and you should be fine.
