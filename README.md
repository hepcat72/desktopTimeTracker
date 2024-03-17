# desktopTimeTracker 7.0

WARNING: This is not a plug and play app.  It is a pair of scripts with dependencies that you must install yourself.  I use it myself to track my own time, but I figured it was straightforward enough that others may be able to use it, if they knew what they were doing.

The perl script to create the plots has a command line interface, but the script itself is not terribly readable.  I wrote it quickly.  So I suggest running it to get the usage instead of reading it.

See this stack post for an overview and examples with screenshots: https://apple.stackexchange.com/a/470628/55021

## What is this?

This is a pair of scripts that, together with a little effort, can be used to track time spent on each desktop in Mission Control.  There is a little manual setup required.  You must:

1. Create a Stickies window on each desktop (following the instructions below).
2. Set up a cron job to run once a minute (or however frequently you want to log which desktop you are on).
3. Optionally configure specific apps whose usage should be counted differently (e.g. "Zoom" is "Meeting" time).  A few example defaults are already set in desktopTimeTracker.osa.
4. When you run the AppleScript (desktopTimeTracker.osa) the first time, you will have to enable permissions, as prompted by macOS.

## Purpose

Track time spent on projects that are organized by desktop (or custom-set app).  

## Author

Robert Leach
Research Software Engineer
Princeton University
rleach@princeton.edu

## Installation

### 1. Label each desktop using a Stickies.app window, using either a provided convenience script, or manually (following the specific instructions below):

#### Using `trackThisDesktop.osa`

`trackThisDesktop.osa` can be run from the command like:

```
osascript trackThisDesktop.osa
```

It will prompt you to enter a 1-word project name and create a Stickies window that `desktopTimeTracker.osa` (running in a cron job) will recognize and extract the project name whenever you are on that desktop.

Note that this does not fix the issue of Stickies windows moving after reboot.  If the windows already exist, you will have to put them back on their original desktops after reboot.  I have a fairly heavy-handed script I use myself for automating this task (but it currently requires a second monitor).  I may try and adapt it in a lightweight manner for this repo at some point in the future.  Until then, hopefully `trackThisDesktop.osa` will make at least creating the initial labels a bit easier.

#### Manual method

Put a Stickies.app sticky note on each desktop containing a single-word desktop name (as the first word on the first line of the sticky).  The first line must also contain the string "dtop" (without the quotes).

Example:

    MyProject  dtop

Be sure that Stickies.app is not assigned to any desktop.

### 2. Create a cron job

Open your crontab file with:

    crontab -e

Add a command like this to your cron file: `osascript desktopTimeTracker.osa >> projects.log`

Example:

    * * * * MON-FRI osascript /path/to/desktopTimeTracker.osa >> /path/to/project_log.txt

The above, on macOS, runs once a minute on weekdays
Note that the first time it runs, you will need to set permissions.  I have not yet documented these permissions, so you're on your own.

### 3. OPTIONAL: Install gnuplot

The perl script (`desktopTimeTrackerPlots.pl`) calls `gnuplot`, but it also generate plottable data files, so that you can use whatever plotting tool you wish.  But if you want the script to create PNG files with your time plotted in bar plots, you must install `gnuplot`.

https://ports.macports.org/port/gnuplot/

## Usage

This logging script (`desktopTimeTracker.osa`) is not intended to be run manually.  See "Installation" above.  But you can try it to see how it works.  Run this on the command line using the osascript utility like this:

    osascript desktopTimeTracker.osa

After having logged your desktop activity for awhile, you can plot the time spent on each desktop using the included perl script.  The script uses gnuplot (a dependency) to plot project activity by day or by project.  Run the script without any arguments to see its usage:

    desktopTimeTrackerPlots.pl