require 'mackerel-rb'
require 'date'
require 'json'
require 'yaml'

def conf
  @_conf ||= YAML.load_file(ENV['MACKERE_AVR_CONF'] || './avr.yml')
  @_conf
end

def start_day(period)
  d = Date.today
  case period
  when "month"
    (d - 30).to_time.to_i
  when "week"
    (d - 7).to_time.to_i
  else
    raise "can't support period #{period}"
  end
end

def period_to_sec(period)
  case period
  when "month"
    86400 * 31
  when "week"
    86400 * 7
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

conf.each do|_,t|
  monitor_name = t['monitor_name']
  service_name = t['service_name']
  period = t['period']
  result = 0
  lastId = nil
  done = nil

  loop do
    query_param.merge!({nextId: lastId}) if lastId
    Mackerel.alerts(lastId ? query_param.merge({nextId: lastId}) : query_param).each do |a|
      if a.openedAt < start_day(period)
        done = true
        break
      end

      if a.monitorId == monitor_id(monitor_name)
        result += (a.closedAt ? a.closedAt : start_day(period)) - a.openedAt
      end
      lastId = a.id
    end
    break if done
  end

  Mackerel.create_service_tsdb(service_name, [{
    name: "availability_ratio.#{monitor_name}",
    time: Time.now.to_i,
    value: result == 0 ? 100 : (period_to_sec(period) - result).to_f / period_to_sec(period) * 100
  }])
end
