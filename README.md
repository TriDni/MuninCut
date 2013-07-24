MuninCut
========

This script allows to delete some time period on Munin's Graph. 

French documentation : http://triden.org/index.php/Munin_-_muninCut

##Requirements

    cpan -i Term::Pager
    cpan -i Term::ReadKey
    cpan -i HTTP::Date

##Usage

Just launch muninCut.pl with a user which has rights to modify /var/lib/munin/.

    ./muninCut.pl
    
##Steps

Script load Munin's parameters : 

    Working On Munin's Datafile, please wait few seconds ...
    Search for Component (Server) :
    
You can search for some munin-node : 

    Search for Component (Server) : ipr
    
And you can a result :

    [1] ipr-mta01.fr9t.rbs-fr.net
    [2] ipr-mta02.fr9t.rbs-fr.net
    [3] ipr-mtamaster.fr9t.rbs-fr.net
    [4] ipr-radius01.fr9t.rbs-fr.net
    [5] ipr-radius02.fr9t.rbs-fr.net
    [6] ipr-radius.fr9t.rbs-fr.net
    [7] ipr-rproxy01.fr9t.rbs-fr.net
    [8] ipr-nagios01.intra.rbs-fr.net
    
When you have identified munin-node that is interestingfor you, press "q" to quit "more", and select ID :

    Which Component's ID is interesting for you (only one) ? 8
    
Next, all munin-node's plugins will be printed :

    [1] apache_accesses
    [2] apache_volume
    [3] canopsis_mongo_size
    [4] cpuspeed
    [5] cpu
    [6] df
    [7] df_inode
    [8] diskstats_iops
    [9] diskstats_latency
    [10] diskstats_throughput
    
Then select ID :

    Which Resource's ID is interesting for you (only one) ? 5
    
Next, all plugin's metrics will be printed :

    [1] idle
    [2] iowait
    [3] irq
    [4] nice
    [5] softirq
    [6] steal
    [7] system
    [8] user
    
Again, select ID :

    Which Metric's ID is interesting for you (only one) ? 1
    
And last, select the time period which will be setted to NaN :

    Please set begin date (format : 'yyyy-MM-dd hh:mm:ss') : 2013-05-21 00:00:00
    Please set end date (format : 'yyyy-MM-dd hh:mm:ss') : 2013-05-21 10:00:00

Note : Changes will appear on next munin-update / munin-graph.
