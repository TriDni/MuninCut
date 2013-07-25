#!/usr/bin/perl

# License
# GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt)
# Authors
# DENNI Tristan (http://triden.org)
#
# Version Note
#
# Add syslog functionnality
# Resolve some bugs (permissions problems, metric ID control bugs)

use strict;
use warnings;
use Term::Pager;
use Term::ReadKey;
use HTTP::Date;
use Sys::Syslog qw( :DEFAULT setlogsock);

my $syncPath = "/var/lib/munin/";
my (%component, %resource);

system("clear");

print "/!\\ IMPORTANT /!\\\nNote that you have to execute this script with some user that can edit, chmod and chown on /var/lib/munin/\n\n";
print "\nWorking On Munin's Datafile, please wait few seconds ...\n\n";
$syncPath = addEndSlash($syncPath);
my $rrdObj = buildRrdObj($syncPath);
my ($columns, $rows) = GetTerminalSize();

my $i = 1;
print "Search for Component (Server) : ";
my $searchComponent = <>;
chomp($searchComponent);
print "\n";

foreach my $plugin (@$rrdObj) {
  if (${$plugin}{component} =~ /.*($searchComponent).*/) {
		foreach my $j (keys %component) {
			if ($component{$j} eq ${$plugin}{component}) {
				delete($component{$j});
				$i--;
				}
			}		
		$component{$i} = ${$plugin}{component};
		$i++;
		}
	}
my $printComponent = Term::Pager->new( rows => $rows, cols => $columns);
$printComponent->add_text("\n");
foreach my $key ( sort {$a<=>$b} keys %component) {
    $printComponent->add_text("[$key] $component{$key}\n");
	}
$printComponent->more();

if (not keys %component) { print "\nNo Result !\n"; exit; }

print "\nWhich Component's ID is interesting for you (only one) ? ";
my $selectedComponent = <>;
chomp($selectedComponent);
idControl($selectedComponent, %component);
print "\n";
$i = 1;

foreach my $plugin (@$rrdObj) {
	if (${$plugin}{component} eq $component{$selectedComponent}) {
		foreach my $j (keys %resource) {
            if ($resource{$j} eq ${$plugin}{resource}) {
                delete($resource{$j});
                $i--;
                }
            }       
        $resource{$i} = ${$plugin}{resource};
        $i++;
		}
	}

my $printResource = Term::Pager->new( rows => $rows, cols => $columns);
$printResource->add_text("\n");
foreach my $key ( sort {$a<=>$b} keys %resource) {
    $printResource->add_text("[$key] $resource{$key}\n");
    }
$printResource->more();

print "\nWhich Resource's ID is interesting for you (only one) ? ";
my $selectedResource = <>;
chomp($selectedResource);
idControl($selectedResource, %resource);
print "\n";
$i = 1;
my @metricArray;

foreach my $plugin (@$rrdObj) { 
	if (${$plugin}{component} eq $component{$selectedComponent} && ${$plugin}{resource} eq $resource{$selectedResource}) {
		my $metricTmp = ${$plugin}{metric};
		foreach my $metric (@$metricTmp) {
			my $this = {"id", $i, "name", ${$metric}{name}, "path", ${$metric}{path}};
			bless($this, ${$metric}{name});
			push(@metricArray, $this);
			$i++;
			}
		last;
		}
	}

my $printMetric = Term::Pager->new( rows => $rows, cols => $columns);
$printMetric->add_text("\n");
foreach my $metric (@metricArray) {
	$printMetric->add_text("[".${$metric}{id}."] ".${$metric}{name}."\n");
	}
$printMetric->more();

print "\nWhich Metric's ID is interesting for you (only one) ? ";
my $selectedMetric = <>;
chomp($selectedMetric);
objIdControl($selectedMetric, @metricArray);
print "\n";

my $path;
foreach my $metric (@metricArray) {
	if (${$metric}{id} eq $selectedMetric) {
		$path = ${$metric}{path};
		last;
		}
	}

system("clear");
print "\nPlease set begin date (format : 'yyyy-MM-dd hh:mm:ss') : ";
my $beginDate = <>;
chomp($beginDate);
dateControl($beginDate);
my $beginTimestamp = str2time($beginDate);

print "\n\nPlease set end date (format : 'yyyy-MM-dd hh:mm:ss') : "; 
my $endDate = <>;
chomp($endDate);
dateControl($endDate);
my $endTimestamp = str2time($endDate); 
if ($endTimestamp && $beginTimestamp &&($endTimestamp < $beginTimestamp)) { print "\nBegin date must be younger than End date !\n"; exit; }

if (-e "/tmp/temp.xml") { unlink "/tmp/temp.xml"; }
    `rrdtool dump $path>/tmp/temp.xml`;
    print "\n\n[1/6] Dump RRD file";
    open(TMP, "/tmp/temp.xml");
    open(XML, ">/tmp/tmprrd.xml");

    foreach my $line (<TMP>) {
        my ($timestamp) = $line =~ /<!--.*(\d{10})\s-->/;
        my ($value) = $line =~ /<row><v>(.*)<\/v><\/row>/;
		if (defined $value && defined $timestamp) {
			if (($timestamp <= $endTimestamp) && ($timestamp >= $beginTimestamp)) {
				$line =~ s/<row><v>.*<\/v><\/row>/<row><v> NaN <\/v><\/row>/;		
				} 
			}
		print XML $line;
		}
    print "\n\n[2/6] Build new RRD";
    unlink "/tmp/temp.xml";
    print "\n\n[3/6] Delete Dump";
    close(TMP);
    close(XML);
    unlink $path;
    `rrdtool restore /tmp/tmprrd.xml $path`;
    print "\n\n[4/6] Restore RRD";
    system("chmod 664 ".$path);
    system("chown munin:munin ".$path);
    print "\n\n[5/6] CHMOD and CHOWN new RRD";
    unlink "/tmp/tmprrd.xml";
    
    setlogsock('unix');
    openlog('muninCut', '', 'user');
    syslog('info', "cutting RRD|Begin:$beginDate($beginTimestamp)|End:$endDate($endTimestamp)|Path:$path");
    print "\n\n[6/6] Writing Syslog (muninCut)\n";

sub dateControl { 
	my ($date) = @_;
	if (not $date =~ /^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}$/) { 
		print "\nPlease use expected datetime format !\n"; 
		exit; 
		}	
}

sub objIdControl {
	my ($id, @obj) = @_;
	my $check = 1;
	if (defined keys @obj) {
		foreach my $metric (@obj) {
			if (${$metric}{id} eq $id) {
				$check = 1;
				last;
			} else {
				$check = 0;
				}
			}
		}
	else {
		$check = 0;
		}
	if ($check == 0) {
		print "\nUnknown ID ! \n\n";
		exit;
		}
}

sub idControl {
	my ($id, %hash) = @_;
	if (not %hash or !defined $hash{$id}) {
		print "\nUnknown ID !\n\n";
		exit;
		}
}

sub addEndSlash {
	my ($string) = @_;
	if (not $string =~ /.*\/$/) { $string .= "/"; }
	return $string;
}

sub buildRrdObj {

	my ($path) = @_;
	$path = addEndSlash($path);
	my $datafile = $path."datafile";
	my ($domain, $node, $plugin, $instance, $type, $value, $unit, $resource, $component);
	my (@obj, %metric, @metricObj);
	my ($tmpDomain, $tmpNode, $tmpPlugin, $tmpMetric, $tmpUnit);

	`sort -V $datafile > /tmp/tmp_datafile`;

	open(DATAFILE, "/tmp/tmp_datafile");
	while(<DATAFILE>){
	if ($_ =~ /^version.*/) { next; }
		($plugin) = $_ =~ /^.*;.*:([\w*|\-*]*)\.[\w*|\-*]*.*$/;
		($domain) = $_ =~ /^(.*);.*/;
		($node) = $_ =~ /^.*;(.*):.*/;
		if ((not $_ =~ /.*\.graph_.*\s+.*$/) && (not $_ =~ /.*\.host_name\s+.*$/))  {
			($instance) = $_ =~ /^.*;.*:[\w*|\-*]*\.([\w*|\-*|\.*]*)\.[\w*|\-*]*\s+.*$/;
			($type) = $_ =~ /^.*;.*:[\w|\.|\-]*\.([\w*|\-*]*)\s+.*$/;
			($value) = $_ =~ /\s+(.*)$/;
			if ((%metric && (defined $tmpMetric && $tmpMetric ne $instance) || (defined $tmpPlugin && $tmpPlugin ne $plugin)) && (defined $metric{id} && defined $metric{name} && defined $metric{type} && defined $metric{path})) {
				my $this = {"id", $metric{id}, "name", $metric{name}, "type", $metric{type}, "min", $metric{min}, "max", $metric{max}, "path", $metric{path}};
				bless($this, $metric{id});
				push(@metricObj, $this);
				undef %metric;
				}
			$metric{id} = $instance;
			if ($type eq "min") {
				$metric{min} = emptyVal($value);
				}
			elsif ($type eq "max") {
				$metric{max} = emptyVal($value);
				}
			elsif ($type eq "label") {
				$metric{name} = emptyVal($value);
				}
			elsif ($type eq "type") {
				$metric{type} = emptyVal($value);
				}
			#génération du chemin du rrd pour la métrique
			if (defined $metric{type} && defined $domain && defined $node && defined $plugin && defined $metric{id}) {
				my $metricInstance = $metric{id};
				$metricInstance =~ s/\./-/;
				my $rrdPath = $path.$domain."/".$node."-".$plugin."-".$metricInstance.type2Ext($metric{type});
				$metric{path} = $rrdPath;
				}
			$tmpMetric = $instance;
			} 
		else { #plugin config
			if (defined $tmpPlugin && $tmpPlugin ne $plugin && %metric && (defined $metric{id} && defined $metric{name} && defined $metric{type} && defined $metric{path})) {
       	                	my $this = {"id", $metric{id}, "name", $metric{name}, "type", $metric{type}, "min", $metric{min}, "max", $metric{max}, "path", $metric{path}};
                        	bless($this, $metric{id});
                        	push(@metricObj, $this);
                        	undef %metric;
                        	}
			($type) = $_ =~ /.*\.(graph_\w*)\s.*$/;
			if (emptyVal($type) eq "graph_title") {
				($resource) = $_ =~ /.*\.graph_title\s(.*)$/;
				}
			elsif (emptyVal($type) eq "graph_vlabel") {
				($unit) = $_ =~ /.*\.graph_vlabel\s(.*)$/;
				}
			}
	        if ((defined $tmpPlugin && $tmpPlugin ne $plugin)) {
			my @tmpMetric = @metricObj; #nécessaire pour éviter la réinitialisation de "metric" sur l'objet
                	my $this = {"component", $tmpNode, "resource", $tmpPlugin, "unit", emptyVal($unit), "metric", \@tmpMetric};
	                bless($this, $tmpDomain."-".$tmpNode."-".$tmpPlugin);
		        push(@obj, $this);
			undef @metricObj;
       		        }
		$tmpDomain = $domain;
		$tmpNode = $node;
		$tmpPlugin = $plugin;
		$tmpUnit = $unit;
		}
	unlink "/tmp/tmp_datafile";
	return \@obj;
}

sub emptyVal {
	my ($value) = @_;
	if (!defined $value) {
		$value = "";
		}
	elsif ($value =~ /^\s*U\s*$/) {
		$value = "";
		}
	elsif ($value =~ /^\s*.*/) {
		$value =~ s/^\s+//;
		}
	elsif ($value =~ /.*\s*$/) {
		$value =~ s/\s+$//;
		}
	return $value;	
}

sub type2Ext {
	my ($value) = @_;
	my $return;
	if ($value =~ /GAUGE/) {
		$return = "-g.rrd";
		}
	elsif ($value =~ /DERIVE/) {
		$return = "-d.rrd";
		}
	elsif ($value =~ /COUNTER/) {
		$return = "-c.rrd";
		}
	elsif ($value =~ /ABSOLUTE/) {
		$return = "-a.rrd";
		}
	return $return;
}
