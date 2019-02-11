#!/bin/bash

# set -x

# if DRAWEMDIR is not defined, assume we need to read the pipeline params 
if [ -z ${DRAWEMDIR+x} ]; then
  . /usr/src/structural-pipeline/parameters/path.sh
fi

# if FSLDIR is not defined, assume we need to read the FSL startup
if [ -z ${FSLDIR+x} ]; then
  if [ ! -f /etc/fsl/fsl.sh ]; then
    echo FSLDIR is not set and there is no system-wide FSL startup
    exit 1
  fi

  . /etc/fsl/fsl.sh
fi 

usage()
{
  base=$(basename "$0")
  echo "usage: $base /path/to/participants.tsv [options]

This script computes the different measurements for the dHCP structural 
pipeline and, if requested, creates pdf reports for the subjects (option 
--reporting).

Arguments:
  participants.tsv              A tab-separated values file containing columns
                                for participant_id, gender and birth_ga in weeks.

                                The participants.tsv must be in the same
                                directory as the derivatives directory made by
                                the structural pipeline.

Options:
  --reporting                   The script will additionally create a pdf 
                                report for each subject, and a group report.    
  -t / -threads  <number>       Number of threads (CPU cores) used (default: 1)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

if [ $# -lt 1 ]; then 
  usage
fi

QC=0
threads=1
command="$@"
participants_tsv="$1"
shift
datadir="$( cd "$( dirname "$participants_tsv" )" && pwd )"
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/scripts
derivatives_dir="$datadir/derivatives"
reportsdir="$datadir/reports"
qc_participants_tsv="$reportsdir/qc_participants.tsv"
workdir="$reportsdir/workdir"
logdir="$datadir/logs"
mkdir -p $logdir

while [ $# -gt 0 ]; do
  case "$1" in
    --reporting)  QC=1; ;;
    -t|-threads)  shift; threads=$1; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

echo "Reporting for the dHCP pipeline

Derivatives directory: $derivatives_dir
participants.tsv:      $participants_tsv
datadir:               $datadir
scriptdir:             $scriptdir
reportsdir:            $reportsdir
logdir:                $logdir
reporting:             $QC

$BASH_SOURCE $command
----------------------------"

if [ ! -f $participants_tsv ]; then
  echo tsv file $participants_tsv not found
  exit 1
fi

if [ ! -d $derivatives_dir ]; then
  echo directory $derivatives_dir not found
  exit 1
fi


################ CHECK PARTICIPANTS ################

echo -e "participant_id\tsession_id\tgender\tbirth_ga" \
  > $qc_participants_tsv

while IFS='' read -r line || [[ -n "$line" ]]; do
  columns=($line)
  subject=${columns[0]}
  gender=${columns[1]}
  birth_ga=${columns[2]}
  if [ $subject = participant_id ]; then
    # header line
    continue
  fi

  if [ ! -d $derivatives_dir/sub-$subject ]; then
    echo $subject not found $derivatives_dir/sub-$subject 
    continue
  fi

  if [ $gender != Male ] && [ $gender != Female ]; then
    echo $subject bad gender $gender
    continue
  fi

  if ! [[ $birth_ga =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo $subject bad birth_ga $birth_ga
    continue
  fi

  for session_path in $derivatives_dir/sub-$subject/ses-*; do
    ses_session=$(basename $session_path)
    session=${ses_session#ses-}

    if [ ! -d $derivatives_dir/sub-$subject/ses-$session ]; then
      echo $subject not found $derivatives_dir/sub-$subject/ses-$session 
      continue
    fi


    T1=sub-${subject}_ses-${session}_T1w.nii.gz
    if [ ! -f $derivatives_dir/sub-$subject/ses-$session/anat/$T1 ]; then
      echo $subject no T1 for session $session
      continue
    fi

    echo -e "${subject}\t${session}\t${gender}\t${birth_ga}" \
      >> $qc_participants_tsv

  done

done < $participants_tsv


################ MEASURES PIPELINE ################

echo "computing volume/surface measurements of subjects..."

while IFS='' read -r line || [[ -n "$line" ]]; do
  columns=($line)
  subject=${columns[0]}
  session=${columns[1]}
  gender=${columns[2]}
  birth_ga=${columns[3]}
  if [ $subject = participant_id ]; then
    # header line
    continue
  fi

  cmd="$scriptdir/compute-measurements.sh $subject $session \
        $derivatives_dir/sub-$subject/ses-$session/anat \
        -d $workdir"
  echo $cmd
  $cmd > $logdir/$subject-$session-measures.log \
      2> $logdir/$subject-$session-measures.err

done < $qc_participants_tsv


# gather measures
echo "gathering volume/surface measurements of subjects..."
measfile=$reportsdir/pipeline_all_measures.csv
rm -f $measfile

# measures
stats="
  volume volume-tissue-regions rel-volume-tissue-regions 
  volume-all-regions rel-volume-all-regions thickness thickness-regions 
  sulc sulc-regions curvature curvature-regions GI GI-regions surface-area 
  surface-area-regions rel-surface-area-regions
"
typeset -A name

# header
lbldir=$scriptdir/../label_names
header="subject ID, session ID, birth_ga"
for c in ${stats}; do
  if [[ $c == *"tissue-regions"* ]];then labels=$lbldir/tissue_labels.csv 
  elif [[ $c == *"all-regions"* ]];then labels=$lbldir/all_labels.csv
  elif [[ $c == *"regions"* ]];then labels=$lbldir/cortical_labels.csv 
  else labels=""; fi
  cname=`echo $c | sed -e 's:-tissue-regions::g'| sed -e 's:-all-regions::g'| sed -e 's:-regions::g'`
  if [ "$labels" == "" ];then header="$header,$cname";
  else
    while read l;do 
      sname=`echo "$l"|cut -f2|sed -e 's:,::g'`;
      header="$header,$cname - $sname";
    done < $labels
  fi
done

# measurements
echo "$header"> $measfile
while IFS='' read -r line || [[ -n "$line" ]]; do
  columns=($line)
  subject=${columns[0]}
  session=${columns[1]}
  gender=${columns[2]}
  birth_ga=${columns[3]}
  if [ $subject = participant_id ]; then
    # header line
    continue
  fi

  subj="sub-${subject}_ses-$session"
  line="$subject,$session,$birth_ga"
  for c in ${stats};do
    if [ -f $workdir/$subject/$subject-$c ]; then 
      line="$line,"`cat $workdir/$subject/$subject-$c |sed -e 's: :,:g' `
    fi
  done
  echo "$line" |sed -e 's: :,:g' >> $measfile

done < $qc_participants_tsv


echo "completed volume/surface measurements"


################ REPORTS PIPELINE ################

if [ $QC -eq 0 ]; then 
  exit
fi

echo "----------------------------
"

echo "computing QC measurements for subjects..."

while IFS='' read -r line || [[ -n "$line" ]]; do
  columns=($line)
  subject=${columns[0]}
  session=${columns[1]}
  gender=${columns[2]}
  birth_ga=${columns[3]}
  if [ $subject = participant_id ]; then
    # header line
    continue
  fi

  subj="sub-${subject}_ses-$session"

  cmd="$scriptdir/compute-QC-measurements.sh $subject $session $birth_ga \
        $derivatives_dir/sub-$subject/ses-$session/anat -d $workdir"
  echo $cmd
  $cmd \
        >> $logdir/$subject-$session-measures.log \
        2>> $logdir/$subject-$session-measures.err

done < $qc_participants_tsv
echo ""

# gather measures
echo "gathering QC measurements of subjects..."

for json in dhcp-measurements.json qc-measurements.json; do
  echo "{\"data\":[" > $reportsdir/$json
  first=1
  while IFS='' read -r line || [[ -n "$line" ]]; do
    columns=($line)
    subject=${columns[0]}
    session=${columns[1]}
    gender=${columns[2]}
    birth_ga=${columns[3]}
    if [ $subject = participant_id ]; then
      # header line
      continue
    fi

    files=`ls $workdir/sub-${subject}_ses-${session}/*$json`
    for f in $files; do 
      line=`cat $f`
      if [ $first -eq 1 ]; then 
        first=0
      else 
        line=",$line"
      fi

      echo $line >> $reportsdir/$json
    done

  done < $qc_participants_tsv
  echo "]}" >> $reportsdir/$json
done

# create reports
echo "creating QC reports..."
cmd="structural_dhcp_mriqc -o $reportsdir -w $workdir 
  --dhcp-measures $reportsdir/dhcp-measurements.json 
  --qc-measures $reportsdir/qc-measurements.json 
  --nthreads $threads"
# echo "running: $cmd"
$cmd >> $logdir/qc.log 2>> $logdir/qc.err
if [ ! $? -eq 0 ]; then
  echo $cmd failed
  exit 1
fi

