# Measurements/Reporting for the dHCP Structural Pipeline

This is an additional package that computes measurements and creates reports
for the dHCP Structural Pipeline.

The measurements include:

* volumes
* cortical surface measurements (surface area, thickness, curvature, sulcal
  depth, gyrification index (GI))

## Developers

[**Antonios Makropoulos**](http://antoniosmakropoulos.com)

## License

The measurements/reporting dHCP structural pipeline are distributed under
the terms outlined in [LICENSE.txt](LICENSE.txt).

## Install and run with docker

You can run the tool in a docker container. This will work on any version
of any platform, is automated, and fairly simple. First, install docker:

https://docs.docker.com/engine/installation/

Pull the latest version of the QC image:

```
$ docker pull biomedia/dhcp-structural-pipeline-measures:latest
```

Then enter:

```
$ docker run --rm -t -v $PWD/data:/data \
    -u $(id -u):$(id -g) \
    biomedia/dhcp-structural-pipeline-measures:latest \
        /data/participants.tsv --reporting
```

This will mount the subdirectory `data` of
your current directory as `/data` in the container, then execute the tool
on the output of `dhcp-structural-pipeline` in that directory. 

The file `participants.tsv` should list the scans to process. For example:

```
participant_id  gender  birth_ga
subject1        Female  44.0
```

The directory containing the `participants.tsv` file should be in the standard
layout for the pipeline. 

This script creates:

File | Description
| -------------  | ------------- |
`derivatives/anat_group_measurements.csv` | CSV file listing all measurements

If the `--reporting` flag is used, it also generates:

File | Description
| -------------  | ------------- |
`derivatives/anat_group.pdf` | PDF that specifies the sessions included
`derivatives/anat_group_qc.pdf` | PDF report for all the sessions
`derivatives/sub-*/ses-*/anat/sub-*_ses-*_qc.pdf` | PDF report for each session

## Rebuild the tool

In the top directory of `structural-pipeline-measure`, use git to 
switch to the branch you want to build, and enter:

```
$ docker build -t biomedia/dhcp-structural-pipeline-measures:latest .
$ docker push biomedia/dhcp-structural-pipeline-measures:latest
```

## Install locally

If you want to work on the code of the pipeline, it can be more convenient to
install locally to your machine. Only read on if you need to do a local
install. 

## Installation

The measurement scripts do not require installation.

The reporting (optional) can be installed as follows:

```
$ pip install packages/structural_dhcp_svg2rlg-0.3 --user
$ pip install packages/structural_dhcp_rst2pdf-aquavitae --user
$ pip install packages/structural_dhcp_mriqc --user
```

## Run

In order to run this pipeline, the dHCP structural pipeline commands/tools
need to be included in the shell PATH by running:

```
$ . [dHCP_structural_pipeline_path]/parameters/path.sh
```

Then run with (eg.):

```
$ ./pipeline.sh ~/vol/dhcp-derived-data/derived_02Jun2018/participants.tsv --reporting
```


