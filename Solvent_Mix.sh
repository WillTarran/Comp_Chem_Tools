#! /bin/bash

print_help()
{
  echo -e "\nSets up and runs COSMO job calculating solubility in solvent mixture between 273 and 373K"
  echo -e "Calculates solubility in binary solvent mix in 10 increments"
  echo -e "Outputs to .txt file named solute_solvent1_solvent2.txt\nOutput contains temperature and solubility in g/L (solution)"
  echo -e "Usage:\n\nSolvent_Mix.sh solute.coskf mpt dH solvent_1.coskf solvent_2.coskf\n"
  echo -e "Solute file must be in execution folder, but solvent files can be specified by relative or absolute path if elsewhere"
  echo -e "Note - Melting point entry in Kelvin [floating point or integer > 9]\ndH entry in kcal/mol [floating point]"
  exit
}
input_error()
{
  echo "For input, a valid .coskf file,  mpt and dH are required as first three arguments"
  echo "with .coskf files for 2 solvents for mixture as fourth and fifth args"
  echo -e "Note - Melting point entry in Kelvin [floating point or integer > 9]\ndH entry in kcal/mol [floating point]"
  exit
}
# check first for non-interactive.  If so, check for solute arguments and populate array from stdin
if [[ "$@" == "-h" || "$@" == "" ]] 
   then print_help
   else
       [[ "$#" == "5" ]] || { echo "Incorrect number of arguments" ; input_error ; }
       args=( "$@" )
       solute_array=( "${args[0]}" "${args[1]}" "${args[2]}" )
       solvent_1=( ${args[3]} )
       solvent_2=( ${args[4]} )
fi

# Check solute and solvent entries are valid
[[ -f "${solute_array[0]}" && "${solute_array[0]}" =~ \.coskf$ ]] && [[ "${solute_array[1]}" =~ [0-9]+\.?[0-9]+ ]] && [[ "${solute_array[2]}" =~ [0-9]+\.[0-9]+ ]] || { echo "Invalid Solute information" ; input_error ; }
[[ -f "$solvent_1" && "$solvent_1" =~ \.coskf$ ]] && [[ -f "$solvent_2" && "$solvent_2" =~ \.coskf$ ]] || { echo "Invalid solvent.coskf" ; input_error ; }

solute_name=$(echo ${solute_array[0]} | sed s/\.coskf$// ) 
solvent_1_name=$(basename -s .coskf $solvent_1 ) 
solvent_2_name=$(basename -s .coskf $solvent_2 ) 

echo "Solubility of $solute_name will be calculated in mixtures of $solvent_1_name and $solvent_2_name"

# run crsprep to update mpt fusion for solute
echo "Prepping ${solute_array[0]} with ${solute_array[1]} K and ${solute_array[2]} kcal"
crsprep -c ${solute_array[0]} -meltingpoint ${solute_array[1]} -hfusion ${solute_array[2]} -savecompound

# # Check for existing output file and print header if new
# formatter="%-10s %-10s %-10s %-60s %-10s\n"
# [[ -f ./${solute_name}_solubility.txt ]] || printf "$formatter"  "Solute" "mpt" "dH" "Solvent" "Solubility g/L" > ${solute_name}_solubility.txt

ID=$RANDOM
while [[ -f ./jobfile$ID ]]
  do ID=$RANDOM
  done

touch ./jobfile$ID            #empty any existing jobfile
chmod u+x ./jobfile$ID    # needs execution to run; . ./jobfile gives bash errors

# For loop to run crsprep to set up SOLUBILITY job for each solvent blend and submit
declare -A result_array
for i in {10..0}
  do frac_1="$(( $i / 10 )).$(( $i % 10 ))"
     j=$(( 10 - $i ))
     frac_2="$(( $j / 10 )).$(( $j % 10 ))"
     echo "Running $solute_name in $frac_1 $solvent_1_name : $frac_2 $solvent_2_name"
     crsprep -t SOLUBILITY -temperature 273.15 -temperature 373.15 -c ${solute_array[0]} -s $solvent_1 -frac1 $frac_1 -s $solvent_2 -frac1 $frac_2 -j ${solute_name}_mix_$j > ./jobfile$ID

     # run job and extract result

     ./jobfile$ID

     # pull temperature column in 1st round
     if [[ "$i" == "10" ]]
     then
         echo -e "$solvent_1_name\n$solvent_2_name" > ${solute_name}_mix_T_tmp
         adfreport ${solute_name}_mix_0.crskf temperature -plain >> ${solute_name}_mix_T_tmp
     fi
     # extract results to tmp file
     echo -e "$frac_1\n$frac_2" > ${solute_name}_mix_${j}_tmp
     adfreport ${solute_name}_mix_$j.crskf solubility-g -plain >> ${solute_name}_mix_${j}_tmp
     rm -rf ${solute_name}_mix_$j.*
  done

[[ -f ./${solute_name}_${solvent_1_name}_${solvent_2_name}.txt ]] && echo "File exists - new data below..." >> ${solute_name}_${solvent_1_name}_${solvent_2_name}.txt
paste ${solute_name}_mix_T_tmp ${solute_name}_mix_{0..10}_tmp >> ${solute_name}_${solvent_1_name}_${solvent_2_name}.txt
sed -e ' /^[[:space:]]*$/d ' ${solute_name}_${solvent_1_name}_${solvent_2_name}.txt # trim blank lines

# delete jobfile
rm -f ./jobfile$ID
rm -f ./${solute_name}_mix_*_tmp
