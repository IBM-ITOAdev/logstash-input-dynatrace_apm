# Logstash Plugin for Dynatrace APM REST API

# Dependencies

Test has been done on Logstash 2.2.0.  

(check the non-IBM JRE version -- TBD)

# dynatrace_apm_rest.rb

This plugin queries Dynatrace APM REST interface for its monitoring metrics (in XML).  Here is the link to the online documentation:
https://community.dynatrace.com/community/pages/viewpage.action?pageId=196642651#DashboardsandReporting%28REST%29-GenerateaDashboardReport

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
  grep resourceid $file > data/$file
  grep -v resourceid $file | sort -t , -k 2 >> sorted/$file
done
```
The line contains *resourceid* is the header.
