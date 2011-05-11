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
    2011-05-10       0.0    21:52:16

Check-out:

    ~:$ t
    2011-05-10       0.1    21:52:16        21:56:48

Check-in again:

    ~:$ t
   2011-05-10       0.1    21:52:16        21:56:48        21:59:02

Print-out:

   ~:$ t -p
   2011-05-10       0.1    21:52:16        21:56:48        21:59:02

Display 'quitting time' to tell when you 8 hours are up:

    ~:$ t -q
    05:54:30

Display 'quitting time' to tell you when half and hour is up:

    ~:$ t -q 0.5
    22:24:30

Add a message to the current day's time:

    ~:$ t -m "Writing a README"
    2011-05-10       0.1    21:52:16        21:56:48        21:59:02        Writing a README

Do a 'dry-run' to see how much time you'd have spent if you stop now:

    ~:$ t -d
    2011-05-10       0.1    21:52:16        21:56:48        21:59:02        22:03:33        Writing a README

And finally, 'repair' the file to recalculate all total times after manually editing the file:

    ~:$ t -r
