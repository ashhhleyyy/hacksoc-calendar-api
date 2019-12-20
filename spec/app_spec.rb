describe 'app' do
  STUB_JSON = <<-JSON
{
  "items": [
    {
      "summary": "Event in June",
      "start": { "dateTime": "2019-06-14T17:00:00Z" },
      "end": { "dateTime": "2019-06-14T18:00:00Z" }
    },
    {
      "summary": "Event in May",
      "start": { "dateTime": "2019-05-21T13:00:00Z" },
      "end": { "dateTime": "2019-05-21T14:00:00Z" }
    },
    {
      "summary": "Event in July 1",
      "start": { "dateTime": "2019-07-01T12:00:00Z" },
      "end": { "dateTime": "2019-07-01T15:00:00Z" }
    },
    {
      "summary": "Event in July 2",
      "start": { "dateTime": "2019-07-05T14:00:00Z" },
      "end": { "dateTime": "2019-07-05T15:00:00Z" }
    },
    {
      "summary": "Event in December",
      "start": { "dateTime": "2019-12-15T12:00:00Z" },
      "end": { "dateTime": "2019-12-15T15:00:00Z" }
    },
    {
      "summary": "Event in January",
      "start": { "dateTime": "2020-01-01T12:00:00Z" },
      "end": { "dateTime": "2020-01-01T13:00:00Z" }
    }
  ]
}
JSON

  before :each do
    allow(CalendarLoader).to receive(:body) do
      StringIO.new(STUB_JSON)
    end
  end

  context '/json' do
    it 'should return the calendar as JSON' do
      get '/json'
      expect(last_response).to be_ok
      expect(last_response.content_type).to start_with 'application/json'
      expect(last_response.body).to eq STUB_JSON
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