#!/bin/bash

usage(){
  echo "Usage: $0 ENVIRONMENT"
  echo
  echo "ENVIRONMENT should be: development|test|production"
} 

ENV=$1

if [ -z "$ENV" ]; then
  usage
  exit
fi

set -x # turns on stacktrace mode which gives useful debug information

#if [ ! -x config/database.yml ] ; then
#  cp config/database.yml.example config/database.yml
#fi

USERNAME=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['database']"`
HOST=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['host']"`

echo "loading recalculating adherence scripts"
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/adherence_calculation.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/recalculate_adherence.sql

echo "fixing retired drugs"
script/runner script/all_after_migration_scripts/fix_program_locations.rb

echo "fixing equivalent daily dose"
script/runner script/all_after_migration_scripts/fix_for_equivalent_daily_dose.rb

echo "adding the hanging pills"
script/runner script/all_after_migration_scripts/include_hanging_pills_to_drug_orders.rb

echo "recalculating adhrence"
script/runner script/all_after_migration_scripts/recalculate_adherence.rb

echo "creating OPD program"
script/runner script/all_after_migration_scripts/creating_patient_opd_program.rb

echo "fixing earliest_start_date"
script/runner script/all_after_migration_scripts/fix_earliest_start_date.rb


echo "done"
