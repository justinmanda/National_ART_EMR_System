require "csv"
def start

  range = []
  raw_arv_numbers = []

  print "Enter maximum arv number : "
  max_number = gets.squish!.to_i rescue 0

  (1..max_number).each do |number|
      range << number
  end

  arv_numbers = PatientIdentifier.find(:all, :conditions => ["identifier_type = 4"]).collect{|x| x.identifier}

  (arv_numbers || []).each do  |arv_number|
      value = arv_number.split("#{PatientIdentifier.site_prefix}-ARV-")[1].to_i
      raw_arv_numbers << value unless value == 0
  end

  missing_arv_numbers = range - raw_arv_numbers

  puts "#{missing_arv_numbers.length} Missing ARV numbers found"

  CSV.open("#{RAILS_ROOT}/tmp/missing_arv_nubers_in_range.csv", "wb") do |csv|
    csv << ["ARV NUMBER" ]
    (missing_arv_numbers|| []).each do |number|

      csv << [number]

    end
  end

end

start