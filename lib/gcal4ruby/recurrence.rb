# Author:: Mike Reich (mike@seabourneconsulting.com)
# Copyright:: Copyright (C) 2010 Mike Reich
# License:: GPL v2
#--
# Licensed under the General Public License (GPL), Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
# Feel free to use and update, but be sure to contribute your
# code back to the project and attribute as required by the license.
#++

class Time
  
  #Returns a ISO 8601 complete formatted string of the time
  def complete
    self.utc.strftime("%Y%m%dT%H%M%S")
  end
  
  def self.parse_complete(value, timezone)
    Time.use_zone(timezone) do 
      unless value.blank?
        if value.include?("T")
          d, h = value.split("T")
          return Time.zone.parse(d+" "+h.gsub("Z", ""))
        else
          value = value.to_s
          return Time.zone.parse("#{value[0..3]}-#{value[4..5]}-#{value[6..7]}")
        end
      end
    end
  end

end

module GCal4Ruby
  #The Recurrence class stores information on an Event's recurrence.  The class implements
  #the RFC 2445 iCalendar recurrence description.
  class Recurrence
    #The event start date/time
    attr_reader :start_time
    #The event end date/time
    attr_reader :end_time
    #the event reference
    attr_reader :event
    #The date until which the event will be repeated
    attr_reader :repeat_until
    #The event frequency
    attr_reader :frequency
    #True if the event is all day (i.e. no start/end time)
    attr_accessor :all_day
    # The timezone the recurring rule is in 
    attr_accessor :timezone
    
    #Accepts an optional attributes hash or a string containing a properly formatted ISO 8601 recurrence rule.  Returns a new Recurrence object
    def initialize(vars = {})
      if vars.is_a? Hash
        vars.each do |key, value|
          self.send("#{key}=", value)
        end
      elsif vars.is_a? String
        self.load(vars)
      end
      @all_day ||= false
    end

    # extracts the timezone from array
    # - 1. finds the "TZID:America/Phoenix" line (returns an array of 1)
    # - 2. Splits the line to separate "TZID" and "America/Phoenix"
    # - 3. Returns the 2nd element from the array  ["TZID", "America/Phoenix"]
    #
    # example: 
    #   ["DTSTART;TZID=America/Phoenix:20101020T120000", 
    #    "DTEND;TZID=America/Phoenix:20101020T130000", 
    #    "RRULE:FREQ=DAILY", "BEGIN:VTIMEZONE", 
    #    "TZID:America/Phoenix", 
    #    "X-LIC-LOCATION:America/Phoenix", 
    #    "BEGIN:STANDARD", 
    #    "TZOFFSETFROM:-0700", 
    #    "TZOFFSETTO:-0700", 
    #    "TZNAME:MST", 
    #    "DTSTART:19700101T000000", 
    #    "END:STANDARD", 
    #    "END:VTIMEZONE"
    #   ]
    def extract_timezone(attrs)
      if tz = attrs.select{|line| line.include?("TZID") && !line.include?(";TZID") }
        return tz.try(:first).try(:split,":").try(:last)
      end
    end
    
    #Accepts a string containing a properly formatted ISO 8601 recurrence rule and loads it into the recurrence object.  
    #Contributed by John Paul Narowski.
    def load(rec)
      @frequency = {}
      attrs = rec.split("\n")
      @timezone = extract_timezone(attrs)
      attrs.each do |val|
        key, value = val.split(":")
        if key == 'RRULE'
          value.split(";").each do |rr| 
            rr_key, rr_value = rr.split("=")
            rr_key = rr_key.downcase.to_sym
            unless @frequency.has_key?(rr_key)
              if rr_key == :until
                @repeat_until = Time.parse_complete(rr_value, @timezone)
              else
                @frequency[rr_key] = rr_value 
              end
            end
          end
        elsif key == 'INTERVAL'
          @frequency[:interval] = value.to_i unless value.blank?
        elsif key.include?("DTSTART;TZID") or key.include?("DTSTART") or key.include?('DTSTART;VALUE=DATE-TIME')
          @start_time ||= Time.parse_complete(value, @timezone)
        elsif key.include?('DTSTART;VALUE=DATE')
          @start_time ||= Time.parse(value)
          @all_day = true
        elsif key.include?("DTEND;TZID") or key.include?("DTEND") or key.include?('DTEND;VALUE=DATE-TIME')
          @end_time ||= Time.parse_complete(value, @timezone)
        elsif key.include?('DTEND;VALUE=DATE')
          @end_time ||= Time.parse(value)
        end
      end
      @frequency[:interval] = 1 unless @frequency[:interval] && @frequency[:interval].to_i > 0
    end
            
    def to_s
      output = ''
      if @frequency
        f = ''
        i = ''
        by = ''
        @frequency.each do |key, v|
          key = key.to_s.downcase
          
          if v.is_a?(Array) 
            if v.size > 0
              value = v.join(",") 
            else
              value = nil
            end
          else
            value = v
          end
          f += "#{key} " if key != 'interval'
          case key
            when "secondly"
            by += "every #{value} second"
            when "minutely"
            by += "every #{value} minute"
            when "hourly"
            by += "every #{value} hour"
            when "weekly"
            by += "on #{value}" if value
            when "monthly"
            by += "on #{value}"
            when "yearly"
            by += "on the #{value} day of the year"
            when 'interval'
            i += "for #{value} times"
          end
        end
        output += f+i+by
      end      
      if @repeat_until
        output += " and repeats until #{@repeat_until.strftime("%m/%d/%Y")}"
      end
      output
    end
    
    #Returns a string with the correctly formatted ISO 8601 recurrence rule
    def to_recurrence_string
      output = ''
      if @all_day
        output += "DTSTART;VALUE=DATE:#{@start_time.utc.strftime("%Y%m%d")}\n"
      else
        output += "DTSTART;VALUE=DATE-TIME:#{@start_time.utc.complete}\n"
      end
      if @all_day
        output += "DTEND;VALUE=DATE:#{@end_time.utc.strftime("%Y%m%d")}\n"
      else
        output += "DTEND;VALUE=DATE-TIME:#{@end_time.utc.complete}\n"
      end
      output += "RRULE:"
      if @frequency
        f = 'FREQ='
        i = ''
        by = ''
        day_of_week = @frequency.delete(:day_of_week)
        @frequency.each do |key, v|
          if v.is_a?(Array) 
            if v.size > 0
              value = v.join(",") 
            else
              value = nil
            end
          else
            value = v
          end
          f += "#{key.to_s.upcase};" if key.to_s.downcase != 'interval'
          case key.to_s.downcase
            when "secondly"
            by += "BYSECOND=#{value};"
            when "minutely"
            by += "BYMINUTE=#{value};"
            when "hourly"
            by += "BYHOUR=#{value};"
            when "weekly"
            by += "BYDAY=#{value};" if value
            when "monthly"
              if day_of_week
                by += "BYDAY=#{value};"
              else
                by += "BYMONTHDAY=#{value};"
              end
            when "yearly"
            by += "BYYEARDAY=#{value};"
            when 'interval'
            i += "INTERVAL=#{value};"
          end
        end
        output += f+by+i
      end      
      if @repeat_until
        output += "UNTIL=#{@repeat_until.strftime("%Y%m%d")}"
      end
      output += "\n"
    end
    
    #Sets the start date/time.  Must be a Time object.
    def start_time=(s)
      if not s.is_a?(Time)
        raise RecurrenceValueError, "Start must be a date or a time"
      else
        @start_time = s
      end
    end
    
    #Sets the end Date/Time. Must be a Time object.
    def end_time=(e)
      if not e.is_a?(Time)
        raise RecurrenceValueError, "End must be a date or a time"
      else
        @end_time = e
      end
    end
    
    #Sets the parent event reference
    def event=(e)
      if not e.is_a?(Event)
        raise RecurrenceValueError, "Event must be an event"
      else
        @event = e
      end
    end
    
    #Sets the end date for the recurrence
    def repeat_until=(r)
      if not  r.is_a?(Date)
        raise RecurrenceValueError, "Repeat_until must be a date"
      else
        @repeat_until = r
      end
    end
    
    #Sets the frequency of the recurrence.  Should be a hash with one of 
    #"SECONDLY", "MINUTELY", "HOURLY", "DAILY", "WEEKLY", "MONTHLY", "YEARLY" as the key,
    #and as the value, an array containing zero to n of the following:
    #- *Secondly*: A value between 0 and 59.  Causes the event to repeat on that second of each minut.
    #- *Minutely*: A value between 0 and 59.  Causes the event to repeat on that minute of every hour.
    #- *Hourly*: A value between 0 and 23.  Causes the even to repeat on that hour of every day.
    #- *Daily*: A true value - will cause the event to repeat every day until the repeat_until date.
    #- *Weekly*: A value of the first two letters of a day of the week.  Causes the event to repeat on that day.
    #- *Monthly*: A value of a positive or negative integer (i.e. +1) prepended to a day-of-week string ('TU') to indicate the position of the day within the month.  E.g. +1TU would be the first tuesday of the month.
    #- *Yearly*: A value of 1 to 366 indicating the day of the year.  May be negative to indicate counting down from the last day of the year.
    #
    #Optionally, you may specific a second hash pair to set the interval the event repeats:
    #   "interval" => '2'
    #If the interval is missing, it is assumed to be 1.
    #
    #===Examples
    #Repeat event daily
    #   frequency = {"daily" => true}
    #
    #Repeat event every Tuesday:
    #   frequency = {"weekly" => ["TU"]}
    #
    #Repeat every first monday of the month
    #   frequency = {"monthly" => "+1MO", :day_of_week => true}
    #
    #Repeat on the 9th of each month regardless of the day
    #   frequency = {"monthly" => 9}
    #
    #Repeat on the last day of every year
    #   frequency = {"Yearly" => 366}
    #
    #Repeat every other week on Friday
    #   frequency = {"Weekly" => ["FR"], "interval" => "2"}
    
    def frequency=(f)
      if f.is_a?(Hash)
        @frequency = f
      else
        raise RecurrenceValueError, "Frequency must be a hash (see documentation)"
      end
    end
  end
end