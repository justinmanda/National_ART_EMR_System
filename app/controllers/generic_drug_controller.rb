class GenericDrugController < ApplicationController

  def name
  drug_list = ['Triomune baby', 'Stavudine', 'Lamivudine', 'Zidovudine', 'and', 'Nevirapine', 'Tenofavir',
              'Atazanavir', 'Ritonavir', 'Abacavir', '(',')'
    ]
    regimen = Regimen.find(:all,:order => 'regimen_index',
      :conditions => ['program_id = ?', 1],
      :include => :regimen_drug_orders)#.to_yaml
    regimen = regimen.map do |r|
			[r.regimen_drug_orders.map(&:to_s)[0].split(':')[0]]
		end
    @names = []
    regimen.uniq.each { |r|
      drug_list.each {|listed|
       r = r.to_s.gsub(listed.to_s, "")
      }
      @names << r
    }
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    @names += other
    # regimens = regimens.map{|d|
    # concept_name = (d.concept.concept_names.typed("SHORT").first ||	d.concept.concept_names.typed("FULLY_SPECIFIED").first).name
    # if d.regimen_index.blank?
    #	["#{concept_name}", d.concept_id, d.regimen_index.to_i]
		#	else
		#		["#{d.regimen_index} - #{concept_name}", d.concept_id, d.regimen_index.to_i]
		#	end
		#}.sort_by{| r | r[2]}.uniq

    #@names = Drug.find(:all,:conditions =>["name LIKE ?","%" + params[:search_string] + "%"]).collect{|drug| drug.name}
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end

  def list_stock
    @drugs = session[:"#{params[:id]}"].sort
    render :layout => 'report'
  end

  def regimen_name_map
  drug_list = ['Triomune baby', 'Stavudine', 'Lamivudine', 'Zidovudine', 'and', 'Nevirapine', 'Tenofavir',
              'Atazanavir', 'Ritonavir', 'Abacavir', '(',')', 'Lopinavir', 'Efavirenz', 'Isoniazid'
    ]
  more_regimen = ["LPV/r (Lopinavir and Ritonavir syrup)", "LPV/r (Lopinavir and Ritonavir 200/50mg tablet)","LPV/r (Lopinavir and Ritonavir 100/25mg tablet)","EFV (Efavirenz 600mg tablet)", "EFV (Efavirenz 200mg tablet)"]
  other = [ "Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    regimen = Regimen.find(:all,:order => 'regimen_index',
      :conditions => ['program_id = ?', 1],
      :include => :regimen_drug_orders)#.to_yaml
    regimen = regimen.map do |r|
			[r.regimen_drug_orders.map(&:to_s)[0].split(':')[0]]
		end
    
    @names = {}
    regimen.uniq.each { |r|
      fullname = r
      drug_list.each {|listed|
       r = r.to_s.gsub(listed.to_s, "")
      }
      @names["#{fullname}"] = r
    }
    more_regimen.each{|r|
     fullname = r
      drug_list.each {|listed|
       r = r.to_s.gsub(listed.to_s, "")
      }
      @names["#{fullname}"] = r
    }
    other.each{|drug|
      @names[drug] = drug
    }
    return @names

  end

  def add_controllers
    drugs = params[:drug].split(",")
    drugs.each {|drug|
      if drug != ""
        
      end
    }
  end

  def verified_stock
    @delivery_date = params[:observations].first["value_datetime"]
     @drugs =  Regimen.find_by_sql(
      "select distinct(d.name) from regimen r
    inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
    inner join drug d on d.drug_id = rd.drug_inventory_id
    where r.regimen_index is not null
    and r.regimen_index != 0
      ").collect{|drug| drug.name}.compact.sort.uniq rescue []
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    @drugs += other
    @formatted = preformat_regimen
    @drug_short_names = regimen_name_map
    
  end

  def set_receipts

    @delivery_date = params[:observations].first["value_datetime"]
    @drugs =  params[:drug_name]
    @formatted = preformat_regimen
    @drug_short_names = regimen_name_map
    @list = []
    @expiring = {}
    @formatted.each{|drug|
      @drugs.each{|received|
        if drug == received
          @list << drug
         @expiring["#{drug}"] = calculate_dispensed("#{drug}", @delivery_date)
        end
      }
    }

  end

  def delivery
    @formatted = preformat_regimen
    @drugs = regimen_name_map
  end

  def calculate_dispensed(drug_name, delivery_date)
   
    drug_id = Drug.find_by_name(drug_name).id
     #raise params[:name].to_yaml
    current_stock = Pharmacy.current_stock_as_from(drug_id , Pharmacy.first_delivery_date(drug_id),delivery_date.to_date)
     
      expiry = 0
      Pharmacy.currently_expiring_drugs(delivery_date.to_date, drug_id).each {|stock|
        #raise stock[1].to_yaml
        expiry += stock[1]["delivered_stock"]

      }
      if current_stock > 0 and current_stock <= expiry
          expiry = current_stock
      elsif current_stock > expiry
          expiry = expiry 
      else
         expiry = 0
      end
     
    return  expiry
  end

  def create_stock
    params[:obs].each{ |delivered|
      next delivered[1]["amount"] == 0
      drug_id = Drug.find_by_name(delivered[0]).id rescue []
      delivery_date = params[:delivery_date].to_date
      date_value = delivered[1]['date'].split("/")
      current_century = Date.today.year.to_s.chars.each_slice(2).map(&:join)[0].to_i
      
      year = date_value[1]
      month = date_value[0]
      expiry_date = "#{current_century}#{year}-#{month}-#{01}".to_date rescue Date.today
      expiry_date += 1.months
      expiry_date -= 1.days
      
      number_of_tins = delivered[1]["amount"].to_i.to_f
      number_of_pills_per_tin = delivered[1]["expire_amount"].to_i.to_f
      number_of_pills = (number_of_tins * number_of_pills_per_tin)
      barcode = params[:identifier]
      Pharmacy.new_delivery(drug_id,number_of_pills,delivery_date,nil,expiry_date,barcode)
    }
    #add a notice
    #flash[:notice] = "#{params[:drug_name]} successfully entered"
    redirect_to "/clinic"   # /management"
  end

  def edit_stock
    if request.method == :post
      edit_reason = params[:reason] rescue ""
      encounter_datetime = params[:delivery_time].to_dte rescue Date.today
      params[:obs].each{ |delivered|
              next if delivered[1]["amount"].to_i == 0
              drug_id = Drug.find_by_name(delivered[0]).id rescue []
              encounter_datetime = params[:delivery_time].to_dte rescue Date.today
              date_value = delivered[1]['date'].split("/")
              current_century = Date.today.year.to_s.chars.each_slice(2).map(&:join)[0].to_i

              year = date_value[1]
              month = date_value[0]
              expiry_date = "#{current_century}#{year}-#{month}-#{01}".to_date
              expiry_date += 1.months
              expiry_date -= 1.days

              number_of_tins = delivered[1]["amount"].to_i.to_f
              number_of_pills_per_tin = delivered[1]["expire_amount"].to_i.to_f
              number_of_pills = (number_of_tins * number_of_pills_per_tin)
              if edit_reason == 'Receipts from other clinics'
                Pharmacy.new_delivery(drug_id,number_of_pills,encounter_datetime,nil,expiry_date,edit_reason)
              else
                Pharmacy.drug_dispensed_stock_adjustment(drug_id,number_of_pills,encounter_datetime,edit_reason)
              end
      }
      #flash[:notice] = "#{params[:drug_name]} successfully edited"
      redirect_to "/clinic"   # /management"
    else
    # @delivery_date = params[:observations].first["value_datetime"]
    @drugs =  params[:drug_name]
    @formatted = preformat_regimen
    @drug_short_names = regimen_name_map
    @list = []
    @expiring = {}
    @formatted.each{|drug|
      @drugs.each{|received|
        if drug == received
          @list << drug
        end
      }
    }
     @names = @drugs
    end
  end

  def set_quantity
    
  end

  def verification
    obs = params[:observations]
    edit_reason = obs[0]['value_coded_or_text']
    encounter_datetime = obs[0]['value_datetime']
    drug_id = Drug.find_by_name(params[:drug_name]).id
    pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
    date = encounter_datetime || Date.today
    Pharmacy.verified_stock(drug_id,date,pills) 
    redirect_to "/clinic"   # /management"
  end

  def months_of_stock
    @start_date = params[:start_date].to_date
    @end_date   = params[:end_date].to_date
    
    @month_on_stock = (@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)
    @month_on_stock = 1 if @month_on_stock == 0
    
    @stocks = []
    all_drugs = regimen_name_map
    @formatted = preformat_regimen
    @formatted.each{|drug_id|
      
      drug = Drug.find_by_name("#{drug_id}")
      expected = (Pharmacy.current_stock_as_from(drug.id, @start_date, @end_date) / 60).round
      confirmed_closing = (Pharmacy.verify_closing_stock_count(drug.id,params[:start_date], params[:end_date]) / 60).round
      
      dispensed = (Pharmacy.dispensed_drugs_since(drug.id, params[:start_date], params[:end_date]) / 60).round
      consumption = (dispensed.to_i /  @month_on_stock ) rescue 0
      @months_of_stock = (confirmed_closing.to_i / consumption.to_i) rescue 0
      @months_of_stock = 0 if @months_of_stock.blank?
      
      @months_of_stock = 9 if @months_of_stock > 9
      drug_name = all_drugs["#{drug.name}"] rescue drug.name
      name = "<span>#{drug_name}  <b>#{expected}</b></span>"
      name = "<span>#{drug_name}  <b>#{expected}  No consumption</b></span>" if @months_of_stock == 0
      @stocks << [ name, (@months_of_stock.to_i rescue 0)]
     }

    @stocks = @stocks.to_json
    render :partial => "months_of_stock" and return
  end

  def stoke_movement
    if params[:report_type] != "Stock Movement"
      @drugs = regimen_name_map
    end
  
    obs = params[:observations]
    #raise obs[1]['value_datetime'].to_yaml
    params[:start_date] =  obs[0]['value_datetime']
    params[:end_date] =  obs[1]['value_datetime']
    @start_date = params[:start_date].to_date
    @end_date   = params[:end_date].to_date

    @month_on_stock = (@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)

    @month_on_stock = 1 if @month_on_stock == 0
    if params[:report_type] == "Stock Movement"
        params[:drug_id] = Drug.find_by_name(params[:drug_name]).id
        @drug = Drug.find(params[:drug_id]).name
    end
   

    render :layout => false
  end

  def get_name
    @drug_short_names = regimen_name_map
    id = params[:value] if ! params[:value].blank?
    id = params[:pack_size] if ! params[:pack_size].blank?
    id = params[:short] if ! params[:short].blank?
    name = @drug_short_names[Drug.find(id).name] rescue Drug.find(id).name
  name = name.gsub("(", "")
  name = name.gsub(")", "")
  splitted = name.split(" ")
  i = 1
  letters = " "
   while (i < splitted.length) do
    if splitted[i].upcase == "ISONIAZID"
      i += 1
      next
    end
    if splitted[i].upcase == "OR" or splitted[i].upcase == "H"
      splitted[0] = "#{splitted[0]} #{splitted[i]}"
    else
      letters = "#{letters} #{splitted[i]}"
    end
    i += 1
  end
    name = splitted[0] if ! params[:short].blank?
    name = letters if ! params[:pack_size].blank?
    render :text => "#{name}"
  end

  def stock_report
     if !params[:quarter].blank?
     @end_date = params[:quarter].split('To')[1].squish.split('/')
     @start_date = params[:quarter].split('To')[0].squish.split('/')
     end_day = @end_date[0]
     end_month = @end_date[1]
     end_year = @end_date[2]
     @end_date = "#{end_year}-#{end_month}-#{end_day}".to_date

     start_day = @start_date[0]
     start_month = @start_date[1]
     start_year = @start_date[2]
     @start_date = "#{start_year}-#{start_month}-#{start_day}".to_date
     end
    
    @current_location_name = Location.current_health_center.name rescue ''
    if @start_date.blank?
        @start_date = params[:start_date].to_date if not params[:start_date].blank?
        @end_date = params[:end_date].to_date rescue params[:delivery_date].to_date
    end
   
    #TODO
     current_stock = preformat_regimen
    drugs = regimen_name_map
    @drug_array = drugs
    @formatted = current_stock
    encounter_type = PharmacyEncounterType.find_by_name("New deliveries").id
    #new_deliveries = Pharmacy.active.find(:all,
    #  :conditions =>["pharmacy_encounter_type=?",encounter_type],
    #  :order => "encounter_date DESC,date_created DESC")

    new_deliveries = Pharmacy.find_by_sql("
                     SELECT distinct(drug_id) FROM pharmacy_obs")

    if @start_date.blank?
        encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock').id
        @start_date = Pharmacy.find_by_sql("SELECT * FROM pharmacy_obs
                                     WHERE pharmacy_encounter_type = #{encounter_type}
                                     AND DATE(encounter_date) < '#{@end_date}' AND vaue_text = 'SUPERVISION'
                                    ").first.encounter_date rescue []
        if @start_date.blank?
           @start_date = @end_date - 3.months
           @start_date = @start_date.beginning_of_month
        end
    end
    @days = @end_date - @start_date
    
    @month_on_stock = (@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)

    @month_on_stock = 1 if @month_on_stock == 0
    
    #current_stock = {}
    new_deliveries.each{|delivery|
      current_stock[delivery.drug_id] = delivery if current_stock[delivery.drug_id].blank?
    }

    @stock = {}
     encounter_type_id = PharmacyEncounterType.find_by_name('Tins currently in stock').id
    current_stock.each{|delivery|
      drug = Drug.find_by_name("#{delivery}")
      first_date = Pharmacy.active.find(:first,:conditions =>["drug_id =?",
          drug.id],:order => "encounter_date").encounter_date.to_date rescue nil
      next if first_date.blank?
      next if first_date > @end_date

      start_date = @start_date
      end_date = @end_date
      
     # drug = Drug.find(delivery.drug_id)

      drug_name = drugs["#{drug.name}"]
      if drug_name.blank?
        drug_name = drug.name
      end

     obs = Pharmacy.active.find(:first,
        :conditions =>["pharmacy_encounter_type = ? AND  encounter_date > ? AND encounter_date <= ?
                        AND drug_id = ? AND value_text = 'Supervision'",
        encounter_type_id, @start_date, @end_date, drug.id],
        :order =>'encounter_date DESC,date_created DESC')#.id rescue 0
       end_pharmacy_id = obs.id rescue 0
       expiring_units = obs.expiring_units rescue "Not <br>Available"
       expiry_date = obs.expiry_date rescue "Not <>"
     start_pharmacy_id = Pharmacy.active.find(:first,
      :conditions =>["pharmacy_encounter_type = ? AND encounter_date <= ? AND drug_id = ? AND value_text = 'Supervision'",
      encounter_type_id, start_date, drug.id],
      :order =>'encounter_date DESC,date_created DESC').id rescue 0

      #Pharmacy.verify_stock_count(drug.id,start_date,end_date)
      @stock[drug_name] = {"confirmed_closing" => 0,"dispensed" => 0,"current_stock" => 0 ,
        "confirmed_opening" => 0, "start_date" => start_date , "end_date" => end_date,
        "relocated" => 0, "receipts" => 0,"expected" => 0 ,"drug_id" => drug.id }
      @stock[drug_name]["dispensed"] = Pharmacy.dispensed_drugs_since(drug.id,start_date,end_date)
      @stock[drug_name]["confirmed_opening"] = Pharmacy.verify_stock_count(drug.id,start_date,start_date)
      @stock[drug_name]["confirmed_closing"] = Pharmacy.verify_closing_stock_count(drug.id,start_date,end_date)
      @stock[drug_name]["current_stock"] = Pharmacy.current_stock_as_from(drug.id,start_date,end_date)
      @stock[drug_name]["relocated"] = Pharmacy.relocated(drug.id,start_date,end_date)
      @stock[drug_name]["receipts"] = Pharmacy.receipts(drug.id,start_date,end_date)
      @stock[drug_name]["expected"] = Pharmacy.expected(drug.id,start_date,end_date)
      @stock[drug_name]["end_pharmacy_id"] = end_pharmacy_id
      @stock[drug_name]["start_pharmacy_id"] = start_pharmacy_id
      @stock[drug_name]["expiring_units"] = expiring_units
    }
   
    #@stock.sort{|a,b| (a[0] == b[0]) ? a[1] <=> b[1] : a[0] <=> b[0] }
  end

  def current_stock
    drug = Drug.find_by_name(params[:drug])
    start_date = Date.today
    end_date =  start_date + 30.days
    expected = Pharmacy.expected(drug.id, start_date,end_date)
    render :text => (expected.to_json)
  end

  def stock_chart
    encounter_type = PharmacyEncounterType.find_by_name("Tins currently in stock").id
    #new_deliveries = Pharmacy.active.find(:first,
    # :conditions =>["pharmacy_encounter_type=? AND drug_id =? AND encounter_date >= ? AND encounter_date <= ?",encounter_type, params[:drug_id], params[:start_date], params[:end_date] ],
    #  :order => "encounter_date DESC,date_created DESC")
    
    @stocks = []
    current_stock = {}
    @start_year = params[:start_date].to_date.year
    @start_month = params[:start_date].to_date.month
    @start_day = params[:start_date].to_date.day

    @end_year = params[:end_date].to_date.year
    @end_month = params[:end_date].to_date.month
    @end_day = params[:end_date].to_date.day
    month_difference = (params[:end_date].to_date.year * 12 + params[:end_date].to_date.month) - (params[:start_date].to_date.year * 12 + params[:start_date].to_date.month)
    days_difference = (params[:end_date].to_date.year * 12 + params[:end_date].to_date.month) - (params[:start_date].to_date.year * 12 + params[:start_date].to_date.day)

    start_date = params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')
    
    Pharmacy.find_by_sql("
                    SELECT obs_datetime, value_numeric FROM obs o
                    INNER JOIN concept_name c ON c.concept_id = o.concept_id
                    INNER JOIN encounter e ON e.encounter_id = o.encounter_id
                    INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
                    WHERE et.name = 'dispensing'
                    AND c.name = 'amount dispensed' AND o.value_drug = #{params[:drug_id]}
                    AND obs_datetime >= '#{start_date}' AND obs_datetime <= '#{end_date}'
                    AND o.voided = 0 ORDER BY obs_datetime ASC").each{|dispensed|
                      #raise  Pharmacy.expected(params[:drug_id], params[:start_date], dispensed.obs_datetime).to_yaml
                      @stocks << [dispensed.obs_datetime.to_date.strftime('%Y-%m-%d') ,  ((Pharmacy.expected(params[:drug_id], params[:start_date], dispensed.obs_datetime) / 60).round)]
                    }
   encounter_type = PharmacyEncounterType.find_by_name('New deliveries').id    
    Pharmacy.find_by_sql("
                    SELECT * FROM pharmacy_obs p
                    INNER JOIN pharmacy_encounter_type t ON t.pharmacy_encounter_type_id = p.pharmacy_encounter_type
                    AND pharmacy_encounter_type_id = #{encounter_type}
                    WHERE p.voided=0 AND drug_id=#{params[:drug_id]}
                    AND p.encounter_date >='#{start_date} 00:00:00'
                    AND p.encounter_date <='#{end_date}' ORDER BY encounter_date ASC").each{|received|
                     # raise "here"
                      @stocks << [received.encounter_date.to_date.strftime('%Y-%m-%d') ,  ((Pharmacy.expected(params[:drug_id], params[:start_date], received.encounter_date) / 60).round)]
                    }
     @stocks = @stocks.sort_by{|atr| atr[0]}.to_json
    render :partial => "stoke_chart" and return
  end
  def preformat_regimen
   formatted = [ "ABC/3TC (Abacavir and Lamivudine 60/30mg tablet)",
     "AZT/3TC (Zidovudine and Lamivudine 60/30 tablet)",
     "AZT/3TC (Zidovudine and Lamivudine 300/150mg)",
     "AZT/3TC/NVP (60/30/50mg tablet)",
     "AZT/3TC/NVP (300/150/200mg tablet)",
     "d4T/3TC (Stavudine Lamivudine 6/30mg tablet)",
     "d4T/3TC (Stavudine Lamivudine 30/150 tablet)",
     "Triomune baby (d4T/3TC/NVP 6/30/50mg tablet)",
     "d4T/3TC/NVP (30/150/200mg tablet)",
     "EFV (Efavirenz 200mg tablet)",
     "EFV (Efavirenz 600mg tablet)",
     "LPV/r (Lopinavir and Ritonavir 100/25mg tablet)",
     "LPV/r (Lopinavir and Ritonavir 200/50mg tablet)",
     "LPV/r (Lopinavir and Ritonavir syrup)",
     "ATV/r (Atazanavir 300mg/Ritonavir 100mg)",
     "NVP (Nevirapine 200 mg tablet)",
     "TDF/3TC (Tenofavir and Lamivudine 300/300mg tablet","TDF/3TC/EFV (300/300/600mg tablet)",
     "Cotrimoxazole (480mg tablet)",
     "Cotrimoxazole (960mg)", "INH or H (Isoniazid 100mg tablet)", "INH or H (Isoniazid 300mg tablet)"]
   return formatted
  end
  def date_select
    encounter_type = PharmacyEncounterType.find_by_name("Tins currently in stock").id
    @dates = []
    tracker = []
    Pharmacy.find_by_sql("
                      SELECT distinct(encounter_date) FROM pharmacy_obs WHERE pharmacy_encounter_type = #{encounter_type} AND encounter_date <= '#{Date.today}'
                     AND value_text = 'Supervision' ORDER BY encounter_date DESC").each{|encounter_dates|
                       
                       if tracker.length < 1
                         tracker << encounter_dates.encounter_date
                         next
                       end
                       @dates << "#{encounter_dates.encounter_date.to_date.strftime('%d/%m/%Y')} To #{tracker.last.to_date.strftime('%d/%m/%Y')}"
                       tracker << encounter_dates.encounter_date
                      }
    @goto = params[:goto]
    @goto = 'stock_report' if @goto.blank?
    @drugs =  Regimen.find_by_sql(
      "select distinct(d.name) from regimen r
    inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
    inner join drug d on d.drug_id = rd.drug_inventory_id
    where r.regimen_index is not null
    and r.regimen_index != 0
      ").collect{|drug| drug.name}.compact.sort.uniq rescue []
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    @drugs += other
  end

  def stock_movement_menu
    @formatted = preformat_regimen
    @names = regimen_name_map
  end

  def print_barcode
    if request.post?
      print_and_redirect("/drug/print?drug_id=#{params[:drug_id]}&quantity=#{params[:pill_count]}", "/drug/print_barcode")
    else
      @drugs = Drug.find(:all,:conditions =>["name IS NOT NULL"])
    end
  end
  
  def print
    pill_count = params[:quantity]
    drug = Drug.find(params[:drug_id])
    drug_name = drug.name
    drug_name1=""
    drug_name2=""
    drug_quantity = pill_count
    drug_barcode = "#{drug.id}-#{drug_quantity}"
    drug_string_length =drug_name.length

    if drug_name.length > 27
      drug_name1 = drug_name[0..25]
      drug_name2 = drug_name[26..-1]
    end

    if drug_string_length <= 27
      label = ZebraPrinter::StandardLabel.new
      label.draw_text("#{drug_name}", 40, 30, 0, 2, 2, 2, false)
      label.draw_text("Quantity: #{drug_quantity}", 40, 80, 0, 2, 2, 2,false)
      label.draw_barcode(40, 130, 0, 1, 5, 15, 120,true, "#{drug_barcode}")
    else
      label = ZebraPrinter::StandardLabel.new
      label.draw_text("#{drug_name1}", 40, 30, 0, 2, 2, 2, false)
      label.draw_text("#{drug_name2}", 40, 80, 0, 2, 2, 2, false)
      label.draw_text("Quantity: #{drug_quantity}", 40, 130, 0, 2, 2, 2,false)
      label.draw_barcode(40, 180, 0, 1, 5, 15, 100,true, "#{drug_barcode}")
    end
    send_data(label.print(1),:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{drug_barcode}.lbl", :disposition => "inline")
  end

  def expiring
    @logo = CoreService.get_global_property_value('logo') rescue ''
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    @expiring_drugs = Pharmacy.expiring_drugs(@start_date,@end_date)
    render :layout => "menu"
  end
  
  def removed_from_shelves
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    @drugs_removed = Pharmacy.removed_from_shelves(@start_date,@end_date)
    render :layout => "menu"
  end

  def available_name    
    ids = Pharmacy.active.find(:all).collect{|p|p.drug_id} rescue []
    @names = Drug.find(:all,:conditions =>["name LIKE ? AND drug_id IN (?)","%" + 
          params[:search_string] + "%", ids]).collect{|drug| drug.name}
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end

  def stock_report_edit

    if request.post?
      unless params[:obs].blank?
       
        params[:obs].each{|obs|
          drug_id = Drug.find_by_name(obs[0]).id rescue []
          next if drug_id.blank?
          tins = obs[1]["amount"].to_i
          expiry_date = nil
          if tins != 0
            date_value = obs[1]['date'].split("/")
            year = date_value[1]
            month = date_value[0]
            current_century = Date.today.year.to_s.chars.each_slice(2).map(&:join)[0].to_i
            expiry_date = "#{current_century}#{year}-#{month}-#{01}".to_date
            expiry_date += 1.months
            expiry_date -= 1.days
            expiring_units = obs[1]['expire_amount']
          end
          
          pills = tins * 60
          
          Pharmacy.verified_stock(drug_id, params[:delivery_date],pills, expiry_date, expiring_units, params[:type])
          
        }
        
      else
        obs = params[:observations]
        edit_reason = obs[0]['value_coded_or_text'] rescue nil
        encounter_datetime = params[:encounter_date]
        drug_id = params[:drug_id]
        pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
        date = encounter_datetime || Date.today

        unless edit_reason.blank?
          Pharmacy.drug_dispensed_stock_adjustment(drug_id,pills,date,edit_reason)
        else

         pharmacy = Pharmacy.find(drug_id)
         pharmacy.value_numeric = pills
         pharmacy.save!

        end
      end
      redirect_to :action => 'stock_report', :start_date => params[:start_date],                                  
        :end_date => params[:end_date], :delivery_date => params[:delivery_date]
    else
      @edit_reason = params[:edit_reason]
      @drug_id = params[:drug_id]
      @encounter_date = params[:date]
      @max_date = params[:max_date]
      @start_date = params[:start_date]
      @end_date = params[:end_date]
    end
  end

end
