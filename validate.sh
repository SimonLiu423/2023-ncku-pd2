#!/bin/bash

print_usage () {
	echo "Usage: validate.sh [options] hw_name"
	echo "Options:"
	echo "  -m		Measure execution time"
	echo "  -d		Print diff detail"
	echo "  -n <cnt>	Measure execution time by taking the mean of running the program <cnt> times. Default is 20"
	echo "  -t <path>	Also copies test data from <path>"
	echo "  -f		Use formal test cases"
	exit 1
}
update () {
	echo "Updating validate.sh..."
	SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
	wget -O $SCRIPT_DIR/validate.sh https://raw.githubusercontent.com/SimonLiu423/2023-ncku-pd2/main/validate.sh
	echo "Done!"
	exit 1
}

if [ $# -eq 0 ]; then
	print_usage
fi

if [ "$1" == "update" ]; then
	update
fi

MEASURE_TIME="false"
MEASURE_SAMPLE=20
DIFF_DETAIL="false"
USE_FORMAL="false"
MY_RESULT="false"

while getopts ":mdn:ft" OPTION
do
	case "${OPTION}" in
		m ) MEASURE_TIME="true";;
		d ) DIFF_DETAIL="true";;
		f ) USE_FORMAL="true";;
		n ) MEASURE_SAMPLE=${OPTARG};;
		t ) MY_RESULT="true";;
		\?) echo "$0: Error: Invalid option: -${OPTARG}" >&2; exit 1;;
		: ) echo "$0: Error: option -${OPTARG} requires an argument" >&2; exit 1;;
	esac
done

shift $((OPTIND - 1))		
HW=$1
HW_PATH=$HOME/$HW
HW_EXEC=$HW_PATH/$HW
ANS_PATH=$HW_PATH/answers
RES_PATH=$HW_PATH/results
TEST_PATH=$ANS_PATH

if [ "$USE_FORMAL" == "true" ]; then
	TEST_PATH="$TEST_PATH/formalData"
elif [ "$HW" == "hw5" ] || [ "$HW" == "hw6" ] || [ "$HW" == "hw7" ]; then
	TEST_PATH="$TEST_PATH/testcase{}"
fi

if [ $# -eq 0 ]; then
    echo Expected hw name
    exit 0
fi

hw1_args=(1 120 158 370 850 1000)
hw2_args=(1 2 3)
hw3_args=(0 1 2 3 4 5)
hw4_args=(1 2 3 4)
hw5_args=(1 2 3 4 5)
hw6_args=(1 2 3 4 5)
hw7_args=(1 2 3 4)

hw1_inputs="{}"
hw2_inputs="$TEST_PATH/hw2_test{}.csv"
hw3_inputs="$TEST_PATH/hw3_test{}.csv"
hw4_inputs="$TEST_PATH/hw4_test{}.csv"
hw5_inputs="$TEST_PATH/corpus_00{}.txt $TEST_PATH/query_00{}.txt"
hw6_inputs="$TEST_PATH/corpus{} $TEST_PATH/query{}"
hw7_inputs="$TEST_PATH/corpus{} $TEST_PATH/query{}"

hw1_result="result_{}"
hw2_result="result_{}"
hw3_result="result_{}"
hw4_result="result_{}"
hw5_result="result_00{}"
hw6_result="result_corpus{}_query{}_"
hw7_result="result_"

hw1_args_f=(10 25 68 123 157 235 453 586 787 999)
hw2_args_f=(1 2 3 4 5 6 7 8 9 10)
hw3_args_f=(1 2 3 4 5 6 7 8 9 10)
hw4_args_f=(1 2 3 4 5 6 7 8 9 10)

hw1_inputs_f="{}"
hw2_inputs_f="$TEST_PATH/hw2_test{}.csv"
hw3_inputs_f="$TEST_PATH/problem_{}.csv"
hw4_inputs_f="$TEST_PATH/problem_{}.csv"

hw1_result_f="{}_output.txt"
hw2_result_f="result_{}"
hw3_result_f="answer_{}"
hw4_result_f="answer_{}"


temp=${HW}_inputs
if [[ -z "${!temp}" ]]; then
	echo Script for $HW not found, try updating the script by running ./validate.sh update exit 1
fi

if [ "$USE_FORMAL" == "true" ]; then
	args=${HW}_args_f[@]
	inputs=${HW}_inputs_f
	result=${HW}_result_f
	if [[ -z ${!inputs} ]]; then
		echo "Script for formal data of $HW not found, try updating the script by running ./validate.sh update"
		exit 1
	fi
else
	args=${HW}_args[@]
	inputs=${HW}_inputs
	result=${HW}_result
fi

if [ -e $ANS_PATH ]; then
    rm -rf $ANS_PATH/*
else
	mkdir $ANS_PATH
fi

cp -r /home/share/$HW/* $ANS_PATH/

# if [ -v CUSTOM_PATH ]; then
# 	cp $CUSTOM_PATH/* $ANS_PATH
# fi

if ! [ -e $RES_PATH ]; then
    mkdir $RES_PATH
fi
rm $RES_PATH/*


make --directory $HW_PATH -k clean all

exec_and_measure () {
	N=$1
	cmd="$2"
	for ((i=0; i < $MEASURE_SAMPLE; i++)); do
	    { time echo $N | eval $cmd; } 2>&1
	done | awk -F 'm' '
	    /real/ { real = real + $2; nr++ }
	    /user/ { user = user + $2; nu++ }
	    /sys/  { sys  = sys  + $2; ns++ }
	    END {
	   	 if (nr>0) printf("real %.3fs\n", real/nr);
	   	 if (nu>0) printf("user %.3fs\n", user/nu);
	   	 if (ns>0) printf("sys  %.3fs\n", sys/ns);
	    }'

}

run_tests () {
	for N in ${!args}; do

		echo "[ Test case $N ]"

		if [ "$HW" == "hw6" ] || [ "$HW" == "hw7" ]; then
			for ((i=1; i <= 3; i++)); do
				echo "[ k = $i ]"
				if [ $MEASURE_TIME == "true" ];then
						cmd="xargs -I {} bash -c "'"$HW_EXEC ${!inputs} '$i' > $RES_PATH/${!result}$i"'
						exec_and_measure "$N" "$cmd"
				else
					echo $N | xargs -I {} bash -c "$HW_EXEC ${!inputs} $i > $RES_PATH/${!result}$i"
				fi

				if [ "$DIFF_DETAIL" == "true" ];then
					if [ $MY_RESULT == "true" ]; then
						echo $N | xargs -I {} bash -c "diff -s /tmp/hw6_2/${!result}$i $RES_PATH/${!result}$i"	
					else
						echo $N | xargs -I {} bash -c "diff -s $TEST_PATH/${!result}$i $RES_PATH/${!result}$i"	
					fi 
				else
					if [ $MY_RESULT == "true" ]; then
						echo $N | xargs -I {} bash -c "diff -sq /tmp/hw6_2/${!result}$i $RES_PATH/${!result}$i"
					else
						echo $N | xargs -I {} bash -c "diff -sq $TEST_PATH/${!result}$i $RES_PATH/${!result}$i"
					fi
				fi
			done
		else
			if [ $MEASURE_TIME == "true" ];then
				cmd='xargs -I {} bash -c "$HW_EXEC ${!inputs} > $RES_PATH/${!result}"'
				exec_and_measure "$N" "$cmd"
			else
				echo $N | xargs -I {} bash -c "$HW_EXEC ${!inputs} > $RES_PATH/${!result}"
			fi
			if [ "$DIFF_DETAIL" == "true" ];then
				echo $N | xargs -I {} bash -c "diff -s $TEST_PATH/${!result} $RES_PATH/${!result}"	
			else
				echo $N | xargs -I {} bash -c "diff -sq $TEST_PATH/${!result} $RES_PATH/${!result}"
			fi
		fi

		echo ""
	done
}

run_tests
