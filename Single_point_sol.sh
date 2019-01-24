#! /bin/bash

print_help()
{
  echo -e "\nSets up and runs COSMO job calculating solubility at 300K"
  echo -e "Outputs to .txt file named Solvent_solubility.txt\nEntry can be interactive from command line or data from file"
  echo -e "Interactive Usage:\n\nSingle_point_sol.sh file1.coskf mpt1 dH1 file2.coskf mpt2 dH2 ... filen.coskf mptn dHn solvent.coskf\n"
  echo -e "Data from file:\n\nSingle_point_sol.sh solvent.coskf < data_file.ext\n"
  echo -e "Data file should contain .coskf files with mpt and dH in this order with (any?) whitespace separator"
  echo -e "Data on single or multiple lines is acceptable\n"
  echo -e "Entry using here document should also work - e.g.:\nSingle_point_sol.sh solvent.coskf << EOF"
  exit
}
# check first for non-interactive.  If so, check for solvent argument and populate array from stdin
if [ ! -t 0 ]
  then
       [[ -f "$@" && "$@" =~ \.coskf ]] || { echo "Invalid solvent entry: $@" ; exit ; }
       sol_file="$@" && echo "Solvent is $@"
       args=( $(cat /dev/stdin ) )

# else check for help and if not, pull in args and pop solvent
  else
       [[ "$@" == "-h" || "$@" == "" ]] && print_help
       args=( "$@" )
       last_arg=${args[-1]}
       [[ -f "$last_arg" && "$last_arg" =~ \.coskf ]] || { echo "Invalid solvent entry: $last_arg" ; exit ; }
       unset args[-1]
       sol_file="$last_arg" && echo "Solvent is $last_arg"
fi
solname=$(echo $sol_file | sed s/\.coskf// )

# parse args array;
declare -A input_array
j=0   # iterator for input_array index
for (( i=0 ; i<${#args[*]} ;  i++ ))
  do if [[ -f "${args[$i]}" && "${args[$i]}" =~ \.coskf ]]
     then input_array[$j,0]=${args[$i]}
	(( i++ ))
	[[ "${args[$i]}" =~ [0-9]+\.?[0-9]+ ]] && input_array[$j,1]=${args[$i]} || { echo "Can't identify ${input_array[$j,0]} mpt" ; exit ; }
	(( i++ ))
	[[ "${args[$i]}" =~ [0-9]+\.[0-9]+ ]] && input_array[$j,2]=${args[$i]} || { echo "Can't identify ${input_array[$j,0]} dH" ; exit ; }
	(( j++ ))
     else echo "${args[$i]} not a valid entry or file not found"  && exit
     fi
  done

# Check for existing output file and print header if new
formatter="%-10s %-10s %-10s %-10s\n"
[[ -f ./${solname}_solubility.txt ]] || printf "$formatter"  "Filename:" "mpt" "dH" "Solubility g/L" > ${solname}_solubility.txt

ID=$RANDOM
while [[ -f ./jobfile$ID ]]
  do ID=$RANDOM
  done

touch ./jobfile$ID
chmod u+x ./jobfile$ID    # needs execution to run; . ./jobfile gives bash errors

# for loop running through coskfiles
# run crsprep to update mpt & H fusion
# run crsprep to set up PURESOL job redirected to jobfile script
# run jobfile and collect result

num_files=$(( ${#input_array[*]} / 3 ))
declare -a name_array
for (( i=0 ; i<$num_files ; i++ ))
  do name_array[$i]=$(echo ${input_array[$i,0]} | sed s/\.coskf// )
    echo "Prepping ${input_array[$i,0]} with ${input_array[$i,1]} K and ${input_array[$i,2]} kcal"
    crsprep -c ${input_array[$i,0]} -meltingpoint ${input_array[$i,1]} -hfusion ${input_array[$i,2]} -savecompound
    echo "Running job for ${input_array[$i,0]} in $sol_file"
    crsprep -t PURESOLUBILITY -temperature 300.0 -j ${name_array[$i]}_sol -s ${input_array[$i,0]} -c $sol_file > jobfile$ID
    ./jobfile$ID
    result=$(adfreport ${name_array[$i]}_sol.crskf solubility-g -plain)
    printf "$formatter" ${name_array[$i]} ${input_array[$i,1]} ${input_array[$i,2]} $result >> ${solname}_solubility.txt
    rm -rf ${name_array[$i]}_sol.*
  done

# delete jobfile
rm -f ./jobfile$ID
