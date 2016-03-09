# Logstash Plugin for Dynatrace APM REST API

# Dependencies

Test has been done on Logstash 2.2.0 using Sun JRE version 1.8. 

(Try to avoid IBM JRE 1.7.0 as it caused issues on https)

# dynatrace_apm_rest.rb

This plugin queries Dynatrace APM REST interface for its monitoring metrics (in XML).  Here is the link to the online documentation:
https://community.dynatrace.com/community/pages/viewpage.action?pageId=196642651#DashboardsandReporting%28REST%29-GenerateaDashboardReport

## Dashboard Creation
I have created [this document](https://github.com/IBM-ITOAdev/logstash-input-dynatrace_apm/blob/master/Dynatrace.Dashboard.Creation.pdf) to help you work on the dashboards that will be used by the API.
## Input

| Parameter   | Description                                                                                                                                                             | Optional? |
|-------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|
| hostname    | name or IP address of the Dynatrace server we are going to connect                                                                                                      | No        |
| port        | HTTP port number, default is 8021                                                                                                                                       | Yes       |
| username    | the username used for REST API call                                                                                                                                     | No        |
| password    | the password of the REST username                                                                                                                                       | No        |
| dashboard   | the dashboard that the query will run against                                                                                                                           | No        |
| step_batch  | the interval of each poll in the batch mode, default is 300 seconds                                                                                                     | Yes       |
| step_live   | the interval of each poll in the live mode, default is 300 seconds                                                                                                      | Yes       |
| rangeBegin  | Start time of the poll                                                                                                                                                  | No        |
| rangeEnd    | End time of the poll, default is string 'now'.  This means the plugin will start polling in batch mode from the time defined by rangeBegin and then switch to live mode | Yes       |
| rangeFormat | Time format of rangeBegin and rangeEnd                                                                                                                                  | No        |

### Sample input config

``` ruby
  dynatrace_apm_rest {
    hostname => 'abc.xyz'
    dashboard => 'myDashboard'
    port => 8021
    username => 'xxx'
    password => 'yyy'
    step_batch => 3600
    step_live => 60
    rangeBegin => '2016/02/25 15:50:00 +1100'
    rangeEnd => 'now'
    rangeFormat => "%Y/%m/%d %H:%M:%S %z"
    tags => ['myDashboard']
  }
```
## How it works

### The APM Dashboard
You will have to define a dashboard on the Dynatrace APM side using the Java Web Start fat client (the dashboards on the web pages will not work).  The dashboard defines the data sources that are going to be polled and also the granularity of the metrics.

### Batch and Live Modes
The plugin starts with batch mode by polling the API continuously starting from rangeStart with step width defined by step_batch.  If the rangeEnd is 'now' the plugin will switch to live mode once it reaches the current time.  The live mode will poll the API with intervals defined by step_live.  In live mode, the plugin will sleep for the seconds defined by step_live before the next poll.

If the rangeEnd is not 'now' the plugin will exit once it reaches the rangeEnd.

### Work with IBM Operations Analytics - Predictive Insights and scacsv output
If more than one charts are included in the APM dashboard you will have to sort the scacsv output csv files before feeding into PI because each chart in the dashboard will have its own section in the query result (XML) and scacsv will not take care of the order of the result.
Here is a sample sort command:
``` shell
for file in *csv; do 
  grep timestamp $file > data/$file
  grep -v timestamp $file | sort -t , -k 2 >> sorted/$file
done
```
The line contains *timestamp* is the header.

# Troubleshoot

For some reasons I don't know yet the Dynatrace APM API can come back with less metrics than expected.  For example, if I query one hour of metrics with five minutes interval I should have 12 entries for each resource, however, occationally I get less than 12.

A [script](https://github.com/IBM-ITOAdev/logstash-input-dynatrace_apm/blob/master/utils/metric_check.pl) has been created to check the scacsv generated files and find out those unusual cases.

*Synopsys*:

metric_check [file name] [resource index] [expected number of occurrences]

*[file name]*: name of the csv file

*[resource index]*: one or more index (start from zero) that can construct an unique resource id.  Indexes are separated by colon, e.g. "1:3:4"

*[expected number of occurrences]*: the number of occurrences of unique resource id should occur in the file.  For example, if the metrics are at five minutes interval and the file holds one hour of metrics then the value should be 12.  The script will not report on correct value.

Example:
```
$metric_check.pl DT__1603090900+1100__1603090959+1100.csv 0 12
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time Breakdown:CPU Idle Time - host384 Host-Agent : 4
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time Breakdown:CPU Idle Time - host390 Host-Agent : 4
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time Breakdown:CPU Idle Time - host473 Host-Agent : 5
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time Breakdown:CPU Idle Time - host478 Host-Agent : 4
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time Breakdown:CPU User Time - host384 Host-Agent : 4
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time Breakdown:CPU User Time - host473 Host-Agent : 5
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time Breakdown:CPU User Time - host478 Host-Agent : 4
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time by Host:CPU Total Time - host384 : 4
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time by Host:CPU Total Time - host390 : 4
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time by Host:CPU Total Time - host473 : 5
DT__1603090900+1100__1603090959+1100.csv:APP Dashboard PI:CPU Time by Host:CPU Total Time - host478 : 4
```
The script reports that 11 resources in the file do not have enough (12) metrics. (Index 0 --- the first column in the csv file --- contains the resource id)
