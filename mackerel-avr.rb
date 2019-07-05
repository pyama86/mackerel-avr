require 'mackerel-rb'
require 'date'
require 'json'
require 'yaml'

DAY_OF_MONTH = 30
DAY_OF_WEEK = 7

def conf
  @_conf ||= YAML.load_file(ENV['MACKERE_AVR_CONF'] || './avr.yml')
  @_conf
end

def start_day(period)
  d = Date.today
  case period
  when "month"
    (d - DAY_OF_MONTH).to_time.to_i
  when "week"
    (d - DAY_OF_WEEK).to_time.to_i
  else
    raise "can't support period #{period}"
  end
end

def period_to_sec(period)
  case period
  when "month"
    86400 * DAY_OF_MONTH
  when "week"
    86400 * DAY_OF_WEEK
  else
    raise "can't support period #{period}"
  end
end

def monitor_id(name)
  @_monitors ||= Mackerel.monitors
  @_monitors.find {|m| m.name == name }.id
end

def query_param
  {
    withClosed: true,
  }
end

Mackerel.configure do |config|
  config.api_key = ENV['MACKEREL_APIKEY']
end

open_list = []
close_list = []

conf.each do|monitor_name,t|
  service_name = t['service_name']
  period = t['period']
  result = 0
  lastId = nil
  done = nil

  loop do
    query_param.merge!({nextId: lastId}) if lastId
    Mackerel.alerts(lastId ? query_param.merge({nextId: lastId}) : query_param).each do |a|
      # 処理開始日より古いレコードに到達したら処理終了
      if a.openedAt < start_day(period)
        done = true
        break
      end

      if a.monitorId == monitor_id(monitor_name)
        open_list << a.openedAt
        close_list << a.closedAt
      end
      lastId = a.id
    end
    break if done
  end

  downtime = 0
  atr = 0
  last_close_time = 0

  open_list.size.times do |n|
    downtime += (close_list[n] ? close_list[n] : start_day(period)) - open_list[n]
    if close_list[n]
      atr = close_list[n] - open_list[n]

      last_close_time
      last_close_time = close_list[n]
    end
  end

  mtbf = (period_to_sec(period) - downtime).to_f  / open_list.size / 60 / 60
  mttr = (downtime / open_list.size).to_f / 60 / 60
  availability_ratio = (period_to_sec(period) - downtime).to_f / period_to_sec(period) * 100
  Mackerel.create_service_tsdb(service_name, [
    {
      name: "availability_ratio.#{period}.#{monitor_name}",
      time: Time.now.to_i,
      value: availability_ratio
    },
    {
      name: "mtbf_hour.#{period}.#{monitor_name}",
      time: Time.now.to_i,
      value: mtbf
    },
    {
      name: "mttr_hour.#{period}.#{monitor_name}",
      time: Time.now.to_i,
      value: mttr
    }
  ])
end
