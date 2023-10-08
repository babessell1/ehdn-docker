#!/bin/bash

extract_subject_name() {
    # get sample name from cram/bam filename
    local string="$1"
    local delimiter="_vcpa"
    local subject_name=""

    # Use the delimiter "_vcpa" to split the string and extract the subject name
    subject_name="${string%%$delimiter*}"

    echo "$subject_name"
}


# Function to clean up files associated with a CRAM
cleanup() {
    local cram="$1"
    local bname=$(basename "$cram" .cram)
    
    # Remove CRAM files and associated output
    rm -f "output/${bname}*"
}


process_file() {
    local cram="$1"
    local fasta="$2"

    local fname=$(basename "$fasta")
    local bname=$(basename "$cram" .cram)

    # read only input directories cram/bam, index
    local ro_cram_dir=$(dirname "$cram")

    # Write the success code to a temporary file
    echo "0" > "exitcodes/${bname}-exitcode.txt"

    samtools index -@ 2 "$cram"

    ####################################################################

    # run expansionhunter denovo
    /usr/local/bin/ExpansionHunterDenovo-v0.9.0-linux_x86_64/bin/ExpansionHunterDenovo profile \
        --reads "$cram" \
        --reference "$fasta" \
        --output-prefix output/"$bname" \
        --min-anchor-mapq 50 \
        --max-irr-mapq 40

    # python ehdn_lrdn.py case_sample1.bam case_sample1 ehdn_output.tsv case_sample1.str_profile.json lrdn_output_dir/
    python3 /usr/local/bin/ExpansionHunterDenovo-LRDN/ehdn_lrdn.py "$cram" "$bname" output/"$bname".locus.tsv output/"$bname".str_profile.json output/

    ####################################################################

    # If the process fails, set the failed CRAM variable
    if [ $? -ne 0 ]; then
        # Trigger the cleanup function here to ensure it has a valid failed_cram value
        cleanup "$cram"
        # set task_status to failed depending on which task failed
        # Write the fail exit code to a temporary file
        echo "failed 1: ${bname}"
        echo "1" > "exitcodes/${bname}-exitcode.txt"
    fi

    # extra double check to make sure file exists
    if [ ! -f "output/${bname}-genotype.txt" ]; then
        # Trigger the cleanup function here to ensure it has a valid failed_cram value
        cleanup "$cram"
        # set task_status to failed depending on which task failed
        echo "failed 2: ${bname}"
        echo "1" > "exitcodes/${bname}-exitcode.txt"
        
    fi
}

# command-line (cwl file) arguments
cram1="$1"
cram2="$2"
fasta="$3"
fastaidx="$4"

ro_fa_dir=$(dirname "$fasta")
ro_faidx_dir=$(dirname "$fastaidx")
bname_fa=$(basename "$fasta" .fa)
cp "${ro_faidx_dir}/${bname_fa}.fa.fai" "${ro_fa_dir}/${bname_fa}.fa.fai"

# out = dir to export to
mkdir -p output
mkdir -p out
mkdir -p exitcodes

name1=$(extract_subject_name "$(basename "$cram1" .cram)")
name2=$(extract_subject_name "$(basename "$cram2" .cram)")

# Run the script in parallel for both cram1 and cram2
(
    process_file "$cram1" "$fasta"
) &
(
    process_file "$cram2" "$fasta"
) &


# Wait for all parallel processes to finish
wait

bname1=$(basename "$cram1" .cram)
bname2=$(basename "$cram2" .cram)

echo "bname1: ${bname1}"
echo "bname2: ${bname2}"

# debug echo exit codes
echo $(cat "exitcodes/${bname1}-exitcode.txt")
echo $(cat "exitcodes/${bname2}-exitcode.txt")

# get exit codes to set status
task1_status=$(cat "${name1}-exitcode.txt")
task2_status=$(cat "${name2}-exitcode.txt")

# remove exit code files
# remove exit code files
rm -f -r "exitcodes"

# Check if either of the tasks were killed (exit code is non-zero)
if [ "$task1_status" -ne 0 ] || [ "$task2_status" -ne 0 ]; then
    echo "One or more tasks were killed. Cleaning up..."

    # Determine which task failed and create a TAR for the successful task
    if [ "$task1_status" -eq 0 ]; then  # task 1 succeeded, only create a TAR for task 1
        echo "Task 1 failed. Creating TAR for $name1 only..."
        tar cf "out/${name1}.tar" "output"
        # exit with a pass to ensure tibanna will take what it can get
        exit 0
    elif [ "$task2_status" -eq 0 ]; then  # task 2 succeeded, only create a TAR for task 2
        echo "Task 2 failed. Creating TAR for $name2 only..."
        tar cf "out/${name2}.tar" "output"
        # exit with a pass to ensure tibanna will take what it can get
        exit 0
    else
        echo "Both tasks failed. No TAR files will be created."
        # exit with a failure code
        exit 1
    fi
fi

echo "${name1}___${name2}.tar"
tar cf "out/${name1}___${name2}.tar" "output"

