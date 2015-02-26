1. ```brew install sleepwatcher```  
Follow the instructions for setting up launchd (warning: launchd does not work inside tmux). I would recommend ```cp de.bernhard-baehr.sleepwatcher-20compatibility-localuser.plist ~/Library/LaunchAgents/```  

1. This will setup sleepwatcher to run on sleep and wake events. We also need it on boot (login). To do so either:
  - ```cp timetrckr.plist ~/Library/LaunchAgents/ && launchctl load timetrckr.plist ``` or  
  - create an Application in Automator, with a Run Shell script action which contains ``` source path_to_script```, save it and make it a Login Item in System Preferences.  
  
1. ```chmod 755 path_to_script```  

The script creates a file time.csv and summary.csv on your ~.  
You can of course change this by specifying a different location in app.sh.
