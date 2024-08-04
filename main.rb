#!/usr/bin/env ruby
require 'open-uri'
require 'sinatra'
require 'active_support/all'
require 'json'
require 'date'

GCAL_API_KEY_FILE = File.join(__dir__, '.key')
GCAL_API_KEY = File.exist?(GCAL_API_KEY_FILE) && File.read(GCAL_API_KEY_FILE)
raise 'you must specify the Google Calendar API key in a ".key" file' unless GCAL_API_KEY || defined?(RSpec)

module CalendarLoader
  CALENDAR_ID = 'yusu.org_h8uou2ovt1c6gg87q5g758tsvs@group.calendar.google.com'
  JSON_URL = "https://www.googleapis.com/calendar/v3/calendars/#{CALENDAR_ID}/events?singleEvents=true&maxResults=2500&orderBy=startTime&key=#{GCAL_API_KEY}"

  def self.body
    URI.open(JSON_URL)
  end
end

# An event loaded from the calendar.
Event = Struct.new(:summary, :description, :location, :dtstart, :dtend, :meeting_link)

##
# Converts a calendar event to a hash representation, which can subsequently be
# serialized and sent to a client.
# @param [Icalendar::Event] event The event.
# @return [Hash] The event as a hash.
def event_to_hash(event)
  {
    when_raw: {
      start: event.dtstart,
      end: event.dtend,
    },
    when_human: {
      start_time: event.dtstart.strftime('%H:%M'),
      end_time: event.dtend.strftime('%H:%M'),
      short_start_date: event.dtstart.strftime('%d/%m/%Y'),
      short_end_date: event.dtend.strftime('%d/%m/%Y'),
      long_start_date: event.dtstart.strftime('%A %-d %B %Y'),
      long_end_date: event.dtend.strftime('%A %-d %B %Y')
    },
    summary: event.summary,
    description: event.description,
    location: event.location,
    meeting_link: event.meeting_link,
  }
end

##
# Returns an array of all events in the calendar specified by JSON_URL. This is
# very slow!
# @return [Array<Event>] All events in the calendar.
def all_events
  parsed_body = JSON.parse(CalendarLoader.body.read)
  
  parsed_body['items'].map do |event_json|
    event = Event.new
    event.dtstart      = DateTime.parse(event_json['start']['dateTime'])
    event.dtend        = DateTime.parse(event_json['end']['dateTime'])
    event.summary      = event_json['summary']
    event.description  = event_json['description']
    event.location     = event_json['location']
    event.meeting_link = event_json['hangoutLink']
    event
  end
end

##
# Gets all of the events from the calendar specified in JSON_URL which are in
# the given year and month.
# @param [Integer] year The calendar year.
# @param [Integer] month The calendar month; 1 is January.
# @return [Array<Event>] The events within this month.
def events_in_month(year, month)
  all_events
    .select { |e| e.dtstart.month == month && e.dtstart.year == year }
    .sort_by(&:dtstart)
end

##
# Gets all of the events from the calendar specified in JSON_URL which are in
# a 3-month span, whose centre is the given year and month.
# @param [Integer] year The calendar year.
# @param [Integer] month The calendar month; 1 is January.
# @return [Array<Event>] The events within the given month, the month before,
#   or the month after.
def events_including_surrounding_months(year, month)
  events = all_events

  # Handle the previous month being in a previous year
  prev_month = month - 1
  prev_year = year
  if prev_month == 0
    prev_month = 12
    prev_year -= 1
  end

  # Handle the next month being in the next year
  next_month = month + 1
  next_year = year
  if next_month == 13
    next_month = 1
    next_year += 1
  end

  events
    .select { |e| e.dtstart.month == prev_month && e.dtstart.year == prev_year }
    .sort_by(&:dtstart) +
  events
    .select { |e| e.dtstart.month == month && e.dtstart.year == year }
    .sort_by(&:dtstart) +
  events
    .select { |e| e.dtstart.month == next_month && e.dtstart.year == next_year }
    .sort_by(&:dtstart)
end

before do
  content_type :json
  response.headers['Access-Control-Allow-Origin'] = '*'
end

get '/json' do
  content_type 'application/json'
  CalendarLoader.body
end

get '/events/:year/:month' do |year, month|
  halt 400, { error: 'provide numbers' }.to_json unless /^\d+$/ === year && /^\d+$/ === month

  events_in_month(year.to_i, month.to_i)
    .map { |e| event_to_hash(e) }
    .to_json
end

CALENDAR_ROWS = 6
DAYS_OF_WEEK = 7

get '/events/:year/:month/calendar' do |year, month|
  halt 400, { error: 'provide numbers' }.to_json unless /^\d+$/ === year && /^\d+$/ === month

  year = year.to_i
  month = month.to_i

  events = events_including_surrounding_months(year, month)

  calendar_flat = Array.new(CALENDAR_ROWS * DAYS_OF_WEEK) { {} }

  first_date_of_month = Date.new(year, month, 1)
  commencing_date_of_first_week_of_calendar = first_date_of_month.at_beginning_of_week

  current_date = commencing_date_of_first_week_of_calendar
  (CALENDAR_ROWS * DAYS_OF_WEEK).times do |i|
    calendar_flat[i][:date] = current_date
    calendar_flat[i][:day] = current_date.day
    calendar_flat[i][:in_month] = (current_date.month == month)
    calendar_flat[i][:events] = events.select do |event|
      event.dtstart.year == current_date.year && event.dtstart.month == current_date.month && event.dtstart.day == current_date.day
    end.map { |event| event_to_hash(event) }
    
    current_date = current_date.succ
  end

  calendar_flat.in_groups_of(DAYS_OF_WEEK).reject { |r| r.none? { |c| c[:in_month] } }.to_json
end
