# encoding: utf-8                                                               
########################################################
#
#  Retrieve metrics from Dynatrace APM REST API
# 
#                     Larry Song (larryls@au1.ibm.com)
#
########################################################
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require "net/https"
require "uri"
require 'rubygems'
require 'rexml/document'
require "rexml/streamlistener"

include REXML

class PostCallbacks
  include StreamListener
  
  def remove_comma(s)
    s.sub! ',', ''
    return s.to_s
  end
  
  def initialize(queue, o)
    @queue = queue
    @o = o
  end

  def tag_start(element, attributes)
    if element == 'dashboardreport'
      @dashboardreport = remove_comma(attributes["name"])
    elsif element == 'chartdashlet'
      @chartdashlet = remove_comma(attributes["name"])
    elsif element == 'measure'
      @measure = remove_comma(attributes["measure"])
    elsif element == 'measurement'
      event = LogStash::Event.new()
      event["type"] = "apm-rest-batch"
      event["dashboardreport"] = @dashboardreport
      event["chartdashlet"] = @chartdashlet
      event["measure"] = @measure
      attributes.each do |k, v|
        if k == 'timestamp'
          # to get rid of the last three zeros
          v = (v.to_i/1000).to_s
        end
        event["#{k}"] = v
      end
      # decorate is a protected method, we have to send it back
      @o.send_to_queue(@queue, event)
    end
  end
end

class LogStash::Inputs::DYNATRACE_APM_REST < LogStash::Inputs::Base
  config_name "dynatrace_apm_rest"
  milestone 1

  default :codec, "plain"

  config :hostname, :validate => :string, :required => true
  config :dashboard, :validate => :string, :required => true
  config :port, :validate => :number, :default => 80
  config :username, :validate => :string, :required => true
  config :password, :validate => :string, :required => true
  config :step_batch, :validate => :number, :default => 300
  config :step_live, :validate => :number, :default => 300
  config :rangeBegin, :validate => :string, :required => true
  config :rangeEnd, :validate => :string, :default => 'now'
  config :rangeFormat, :validate => :string, :required => true

  # convert the time (with its format) to epoch
  # e.g: 
  #    convert_to_epoch('2016/02/09 15:05:10 +1100', "%Y/%m/%d %H:%M:%S %z")
  public
  def convert_to_epoch (t, f)
    DateTime.strptime(t,f).to_time.to_i
  end


  public
  def register 
    @epoch_begin = convert_to_epoch(@rangeBegin, rangeFormat)
    if (@rangeEnd == 'now') 
      # to the year 2286
      @epoch_end = 9999999999
    else
      @epoch_end = convert_to_epoch(@rangeEnd, rangeFormat)
    end
  end

  private 
  def https_get(timeBegin, timeEnd)
    u = "https://#@hostname:#@port/rest/management/reports/create/#@dashboard?type=XML\&filter=tf:CustomTimeframe?#{timeBegin}000:#{timeEnd}000"
    puts u
    uri = URI.parse(u)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 600
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(@username, @password)
    resp = http.request(request)
    return resp.body
  end

  public
  def send_to_queue(queue, event)
    decorate(event)
    queue << event
  end

  private
  def call_api(queue, timeBegin, timeEnd)
    r = https_get(timeBegin, timeEnd)
    Document.parse_stream(r, PostCallbacks.new(queue, self))
  end

  public
  def run(queue)
    current = @epoch_begin
    loop do
      if current <= @epoch_end 
        now = Time.now.to_i
        current_step = current + @step_batch
        if current_step > now
          puts "working on #{current} to now: #{now}. This is the last batch call"
          # this is last batch call (to present)
          call_api(queue, current, now)
          current = now
          # we are in the loop for live feed
          loop do
            sleep(@step_live)
            now = Time.now.to_i
            call_api(queue, current, now)
            current = now
          end
        else 
          puts "working on #{current} to #{current_step}"
          call_api(queue, current, current_step)
          current = current_step
        end
      else
        break
      end
    end
  end
  
  public
  def teardown
  end
  
end # class LogStash::Inputs::DYNATRACE_APM_REST
