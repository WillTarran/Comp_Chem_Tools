#! /bin/bash

print_help()
{
  echo -e "\nSets up and runs COSMO job calculating solubility at 300K"
  echo -e "Outputs to .txt file named {inputname}_solubility.txt\nEntry can be interactive from command line or data from file"
  echo -e "Interactive Usage:\n\nSolvent_screening.sh solute.coskf mpt dH solvent_1.coskf solvent_2.coskf ... solvent_n.coskf\n"
  echo -e "Data from file:\n\nSolvent_screening.sh solute.coskf mpt dH < solvents.compoundlist\n"
  echo -e "Data file should contain list of .coskf files for solvents\nNote - filenames must be specified by absolute path or correct relative path"
  echo -e "Data on single or multiple lines is acceptable\n"
  echo -e "Solute file must be in execution folder, but solvent files can be specified by relative or absolute path if elsewhere"
  echo -e "Entry using here document should also work - e.g.:\nSolvent_screening.sh solute.coskf mpt dH << EOF\n"
  echo -e "Note - Melting point entry in Kelvin [floating point or integer > 9]\ndH entry in kcal/mol [floating point]"
  exit
}
input_error()
{
  echo "Incorrect inputs indentified"
  echo "For interactive input, valid .coskf file,  mpt and dH are required as first three arguments"
  echo "with at least one valid solvent .coskf file following"
  echo "For solvent data from file input must be as follows:"
  echo "Solvent_screening.sh solute.coskf mpt dH < solvents.compundlist"
  echo -e "Note - Melting point entry in Kelvin [floating point or integer > 9]\ndH entry in kcal/mol [floating point]"
  exit
}
# check first for non-interactive.  If so, check for solute arguments and populate array from stdin
if [ ! -t 0 ]
  then
       [[ -f "$1" && "$1" =~ \.coskf$ && "$#" == "3" ]] || { echo "Error - non-interactive; \$1 or \$# != 3" ; input_error ; }
       solute_array=( "$@" )
       solvent_array=( $(cat /dev/stdin) )

# else check first three args and populate arrays
  else
       [[ "$@" == "-h" || "$@" == "" ]] && print_help
       [[ "$#" > "3" ]] || { echo "interactive error, <4 arguments" ; input_error ; }
       args=( "$@" )
       solute_array=( "${args[0]}" "${args[1]}" "${args[2]}" )
       unset args[0] args[1] args[2]
       solvent_array=( ${args[*]} )
fi

# Check solute and solvent entries are valid
[[ -f "${solute_array[0]}" && "${solute_array[0]}" =~ \.coskf$ ]] && [[ "${solute_array[1]}" =~ [0-9]+\.?[0-9]+ ]] && [[ "${solute_array[2]}" =~ [0-9]+\.[0-9]+ ]] || { echo "solute array check error" ; input_error ; }
for i in ${solvent_array[*]}
  do [[ -f "$i" && "$i" =~ \.coskf$ ]] || { echo "Invalid solvent.coskf found in input... exiting" ; exit ; }
  done
solute_name=$(echo ${solute_array[0]} | sed s/\.coskf$// )

echo "Solubility of $solute_name will be calculated in ${#solvent_array[*]} solvent[s]"

# run crsprep to update mpt fusion for solute
echo "Prepping ${solute_array[0]} with ${solute_array[1]} K and ${solute_array[2]} kcal"
crsprep -c ${solute_array[0]} -meltingpoint ${solute_array[1]} -hfusion ${solute_array[2]} -savecompound

# Check for existing output file and print header if new
formatter="%-10s %-10s %-10s %-60s %-10s\n"
[[ -f ./${solute_name}_solubility.txt ]] || printf "$formatter"  "Solute" "mpt" "dH" "Solvent" "Solubility g/L" > ${solute_name}_solubility.txt

ID=$RANDOM
while [[ -f ./jobfile$ID ]]
  do ID=$RANDOM
  done

touch ./jobfile$ID
chmod u+x ./jobfile$ID    # needs execution to run; . ./jobfile gives bash errors

# For loop to run crsprep to set up PURESOL job for each solvent and submit
declare -a name_array
for (( i=0 ; i<${#solvent_array[*]} ; i++ ))
  do name_array[$i]=$(basename -s .coskf ${solvent_array[$i]} )
    echo "Prepping and running ${solute_name}_${name_array[$i]} job"
    crsprep -t PURESOLUBILITY -temperature 300.0 -j ${solute_name}_${name_array[$i]}_sol -s ${solute_array[0]} -c ${solvent_array[$i]} > jobfile$ID

    # run job and extract result
    ./jobfile$ID
    result=$(adfreport ${solute_name}_${name_array[$i]}_sol.crskf solubility-g -plain)

    # update result file and remove job files
    printf "$formatter" $solute_name ${solute_array[1]} ${solute_array[2]} ${name_array[$i]} $result >> ${solute_name}_solubility.txt
    rm -rf ${solute_name}_${name_array[$i]}_sol.*
  done

# delete jobfile
rm -f ./jobfile$ID
