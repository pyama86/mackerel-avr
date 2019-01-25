# Mackerl AVR(AvailabilityRatio)
Post the Availability Rate of external monitoring of mackerel to service metrics

## usage
```bash
$ export MACKEREL_APIKEY=xxxxxxxxxx
$ bundle install
$ mv avr.yml.samle avr.yml
$ bundle exec ruby mackerel-avr.rb
```

## conf
- avr.yml
```yaml
profile_name:
  monitor_name: "health-example.com"
  service_name: "example"
  period: "week" # week or month
```

## author
- @pyama86
