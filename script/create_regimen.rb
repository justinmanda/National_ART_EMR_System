puts" THIS SCRIPT WILL HELP YOU TO ADD NEW DRUG REGIMENS\n PLEASE ENTER INPUT CORRECTLY AS PROMPTED\n=====================================================\n"
def start
puts "Enter regimen index eg 0P,0A,1A etc"
STDOUT.flush  
regimen = gets.chomp
puts "The regimen is: #{regimen}"
#capture the regimen concept
puts "Enter the concept_id for the regimen"
concept_id = gets.chomp
puts "the concept for the regimen is: #{concept_id}"
puts "Enter minimum weight for the regimen"
min_weight= gets.chomp
puts "The minimum weight is: #{min_weight}"
puts "Enter the maximum weight for the regimen"
max_weight = gets.chomp
puts "The maximum weight is: #{max_weight}"
date_created = Date.today.strftime("%Y-%m-%d %H:%M")
puts "Created on #{date_created}"
params = {:concept_id=>concept_id.to_i,:regimen_index=>regimen,:min_weight=>min_weight.to_f,:max_weight=>max_weight.to_f,:creator=>1,:retired=>0,:date_created=>date_created,:program_id=>1}
flag = create_regimen(params)
  if flag
	  puts"The regimen and its details have been succefully created"
  end
  
end
def create_regimen(params)
   regimen = Regimen.create(params)
end
start
