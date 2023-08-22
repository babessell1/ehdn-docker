#!/bin/bash

extract_subject_name() {
    # get sample name from cram/bam filename
    local string=$1
    local pattern="([A-Za-z-]+[A-Za-z0-9-]+-[A-Za-z-]+-[A-Za-z0-9]+)"
    local match=""

    if [[ $string =~ $pattern ]]; then
        match="${BASH_REMATCH[1]}"
    fi

    echo "$match"
}

process_file() {
    local cram="$1"
    local fasta="$2"

    local fname=$(basename "$fasta")
    local bname=$(basename "$cram" .cram)

    # read only input directories cram/bam, index
    local ro_cram_dir=$(dirname "$cram")
    local ro_cramidx_dir=$(dirname "$cramidx")
    
    # strling requires idx in same folder
    #cp "${ro_cramidx_dir}/${bname}.cram.crai" "${ro_cram_dir}/${bname}.cram.crai"
    samtools index -@ 2 "$cram"

    # run expansionhunter denovo
    /usr/local/bin/ExpansionHunterDenovo-v0.9.0-linux_x86_64/bin/ExpansionHunterDenovo profile \
        --reads "$cram" \
        --reference "$fasta" \
        --output-prefix output/"$bname" \
        --min-anchor-mapq 50 \
        --max-irr-mapq 40
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

# Run the script in parallel for both cram1 and cram2
(
    process_file "$cram1" "$fasta"
) &
(
    process_file "$cram2" "$fasta"
) &

# Wait for all parallel processes to finish
wait
name1=$(extract_subject_name "$(basename "$cram1" .cram)")
name2=$(extract_subject_name "$(basename "$cram2" .cram)")

tar cf ${name1}___${name2}.tar output
mv ${name1}___${name2}.tar out/${name1}___${name2}.tar
