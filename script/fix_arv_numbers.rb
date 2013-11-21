
def start
  identifiers = get_identifiers
  count = identifiers.length
  site_prefix = PatientIdentifier.site_prefix
  puts ">>>>>> #{count} identifiers"

  (identifiers || []).each do |i|
    number = i.identifier.match(/[0-9](.*)/i)[0] rescue nil
    ActiveRecord::Base.connection.execute <<EOF                              
      UPDATE patient_identifier SET identifier = '#{site_prefix}-ARV-#{number}'                                        
      WHERE patient_identifier_id = #{i.id};        
EOF
    puts ">>>>>>>> identifiers to go: #{count-= 1}"
  end
end

def get_identifiers
  type = PatientIdentifierType.find_by_name('ARV Number')
  PatientIdentifier.find(:all,:conditions =>["identifier_type = ?",type.id])
end


start
