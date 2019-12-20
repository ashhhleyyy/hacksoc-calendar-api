describe 'app' do
  ICAL = <<-ICAL
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//hacksw/handcal//NONSGML v1.0//EN
BEGIN:VEVENT
UID:june@aaronc.cc
DTSTAMP:20190614T170000Z
DTSTART:20190614T170000Z
DTEND:20190614T180000Z
SUMMARY:Event in June
END:VEVENT
BEGIN:VEVENT
UID:may@aaronc.cc
DTSTAMP:20190521T130000Z
DTSTART:20190521T130000Z
DTEND:20190521T140000Z
SUMMARY:Event in May
END:VEVENT
BEGIN:VEVENT
UID:july1@aaronc.cc
DTSTAMP:20190701T120000Z
DTSTART:20190701T120000Z
DTEND:20190701T150000Z
SUMMARY:Event in July 1
END:VEVENT
BEGIN:VEVENT
UID:july2@aaronc.cc
DTSTAMP:20190705T140000Z
DTSTART:20190705T140000Z
DTEND:20190705T150000Z
SUMMARY:Event in July 2
END:VEVENT
BEGIN:VEVENT
UID:december@aaronc.cc
DTSTAMP:20191215T120000Z
DTSTART:20191215T120000Z
DTEND:20191215T150000Z
SUMMARY:Event in December
END:VEVENT
BEGIN:VEVENT
UID:january@aaronc.cc
DTSTAMP:20200101T110000Z
DTSTART:20200101T110000Z
DTEND:20200101T120000Z
SUMMARY:Event in January
END:VEVENT
BEGIN:VEVENT
DTSTART;TZID=Europe/London:20181005T190000
DTEND;TZID=Europe/London:20181005T230000
RRULE:FREQ=WEEKLY;COUNT=5;INTERVAL=2;BYDAY=FR
EXDATE;TZID=Europe/London:20181116T190000
DTSTAMP:20191219T234238Z
UID:7d8eql2ns6gfeair221cfm9hnk@google.com
ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;CN=HackSo
 c Events;X-NUM-GUESTS=0:mailto:yusu.org_h8uou2ovt1c6gg87q5g758tsvs@group.ca
 lendar.google.com
CREATED:20180803T211427Z
DESCRIPTION:In one of the oldest and noblest traditions of HackSoc\, we des
 cend upon a room\, play many boardgames\, and eat much cake. Both boardgame
 s and cake are brought along by members\, so if you do enjoy the events\, p
 lease consider bringing something along.
LAST-MODIFIED:20180820T165910Z
LOCATION:The Room Formerly Known as the Pod
SEQUENCE:0
STATUS:CONFIRMED
SUMMARY:Board Games & Cake
TRANSP:OPAQUE
END:VEVENT
END:VCALENDAR
ICAL

  before :each do
    allow(CalendarLoader).to receive(:body) do
      ICAL
    end
  end

  context '/ical' do
    it 'should return the calendar as an ICAL' do
      get '/ical'
      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with 'text/calendar'
      expect(last_response.body).to eq ICAL
    end
  end

  context '/events/:year/:month' do
    it 'gets all events for the given month' do
      get '/events/2019/07'
      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with 'application/json'
      
      parsed = JSON.parse(last_response.body)
      expect(parsed.length).to eq 2
      
      first, second = *parsed

      expect(first['summary']).to eq 'Event in July 1'
      expect(first['when_human']['short_start_date']).to eq '01/07/2019'

      expect(second['summary']).to eq 'Event in July 2'
      expect(second['when_human']['short_start_date']).to eq '05/07/2019'
    end

    it 'gracefully handles an empty month' do
      get '/events/2019/03'
      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with 'application/json'

      parsed = JSON.parse(last_response.body)
      expect(parsed.length).to eq 0
    end

    it 'obeys EXDATE over a DST boundary' do
      get '/events/2018/11'
      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with 'application/json'

      parsed = JSON.parse(last_response.body)
      expect(parsed.map { |x| x["when_human"]["short_start_date"]}).to eq \
        ["02/11/2018", "30/11/2018"]
    end
  end

  context '/events/:year/:month/calendar' do  
    it 'generates correct output across a year boundary' do
      get '/events/2019/12/calendar'
      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with 'application/json'

      # Check size
      parsed = JSON.parse(last_response.body)
      expect(parsed.length).to eq 6
      expect(parsed.all? { |row| row.length == 7 }).to be true

      # Check 'in_month' flags - some of the calendar is not actually December
      expect(parsed[0][0]['in_month']).to be false
      expect(parsed[0][6]['in_month']).to be true
      expect(parsed[5][2]['in_month']).to be false
      expect(parsed[5][1]['in_month']).to be true

      # Check events
      expect(parsed[2][6]['events'].length).to eq 1
      expect(parsed[2][6]['date']).to eq '2019-12-15'
      expect(parsed[2][6]['events'][0]['summary']).to eq 'Event in December'

      expect(parsed[5][2]['events'].length).to eq 1
      expect(parsed[5][2]['date']).to eq '2020-01-01'
      expect(parsed[5][2]['events'][0]['summary']).to eq 'Event in January'
    end
  end
end