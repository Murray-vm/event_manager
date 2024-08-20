# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers(phone_number)
  phone_number = phone_number.gsub(/\D/, '')
  phone_number[0] = '' if phone_number.length.eql?(11) && phone_number[0].eql?('1')
  phone_number.length.eql?(10) ? phone_number : nil
end

def time_targeting(registration_dates, time_code)
  grouped_hours = registration_dates.each_with_object(Hash.new(0)) do |reg_date, result|
    reg_hour = Time.strptime(reg_date, '%m/%d/%Y  %k:%M').strftime(time_code)
    result[reg_hour] += 1
  end
  grouped_hours.max_by { |_key, value| value }[0]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone_number = clean_phone_numbers(row[:homephone])

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

registration_dates = contents.read[:regdate]
best_reg_hours = time_targeting(registration_dates, '%k')
puts "The best registration hour is #{best_reg_hours}:00"

best_reg_wday = time_targeting(registration_dates, '%A')
puts "The best registration weekday is #{best_reg_wday}s"
