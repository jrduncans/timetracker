Timetracker
===========

**timetracker** is ruby script that can be used to keep track of time spent on a task, storing the information in a simple text file.  It doesn't keep track of multiple tasks, it just stores check-in and check-out times, and calculates totals.

A suggested way to use **timetracker** is to set up an alias that includes the path to the file where you want to store your time data, such as:

    alias t='~/timetracker/timetracker.rb ~/files/timesheet'

Features
--------

Assuming the alias described above, the following commands describe the features of **timetracker**:

Check-in:

    ~:$ t
    2011-05-10     0.0    21:52:16

Check-out:

    ~:$ t
    2011-05-10     0.1    21:52:16    21:56:48

Check-in again:

    ~:$ t
    2011-05-10     0.1    21:52:16    21:56:48    21:59:02

Print-out:

    ~:$ t -p
    2011-05-10     0.1    21:52:16    21:56:48    21:59:02

Undo the most recent entry (pop the last entry):

    ~:$ t -u
    2011-05-10     0.1    21:52:16    21:56:48

List the most recent 5 entries:

    ~:$ t -l
    2013-11-13     8.5    10:22:33    18:52:35
    2013-11-14     7.8    10:26:00    18:16:40
    2013-11-18     9.3    10:30:19    19:49:39
    2013-11-19     8.9    08:59:46    17:55:02
    2013-11-20     0.1    08:51:07    08:56:36

List the most recent 10 entries:

    ~:$ t -l -c 10
    2013-11-04     7.6    10:36:17    18:11:15
    2013-11-06     8.3    10:55:15    19:14:53
    2013-11-07     8.2    10:43:57    18:53:59
    2013-11-08     8.1    09:18:38    17:23:18
    2013-11-11     8.1    09:33:59    17:41:42
    2013-11-13     8.5    10:22:33    18:52:35
    2013-11-14     7.8    10:26:00    18:16:40
    2013-11-18     9.3    10:30:19    19:49:39
    2013-11-19     8.9    08:59:46    17:55:02
    2013-11-20     0.1    08:51:07    08:56:36

Display 'quitting time' to tell when you 8 hours are up:

    ~:$ t -q
    05:54:30

Display 'quitting time' to tell you when half an hour is up:

    ~:$ t -q 0.5
    22:24:30

Add a message to the current day's time:

    ~:$ t -m "Writing a README"
    2011-05-10     0.1    21:52:16    21:56:48    21:59:02    Writing a README

Do a 'dry-run' to see how much time you'd have spent if you stop now:

    ~:$ t -d
    2011-05-10     0.1    21:52:16    21:56:48    21:59:02    22:03:33    Writing a README

And finally, 'repair' the file to recalculate all total times after manually editing the file:

    ~:$ t -r
    
License
--------
Licensed under the Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
