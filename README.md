# Oracle HCM scripts

These scripts automate the extraction and monitoring of Oracle HCM data.


## Deployment

Clone the whole repo to wherever you want or, at the very least, copy the /bin and /cfg folders.

Note that the scripts have configuration variables defined, named `POLL_INTERVAL` and `POLL_COUNT`.  These drive the loop, through which the scripts check whether the extract jobs have completed.  They may need amending, dependent on the length of time the longest Oracle job takes to execute.  The `POLL_INTERVAL` setting in measured in seconds.


## hcm-extract.sh

Runs the HCM extraction utility

- One curl call is made to trigger a data extraction
- A second curl call is repeatedly made to monitor the status of the extraction

The success of the script can be used as a trigger of a subsequent file transfer.


### Parameters

- -j  HCM job name
- -l  number of times to poll when checking status
- -p  password
- -s  host server endpoint url (inc https)
- -u  username
- -w  wait time (in seconds) between status checks


### Return codes

- 00 - if the extraction completes successfully
- 05 - if the extraction does not complete before the script ends
- 09 - if the call to HCM's APIs fails
- 99 - if something else has gone wrong


## bi-extract.sh

Runs HCM's BI reporting utility.

Script operates identically to hcm-extract.sh with the following changes:

### Additional parameters

- -f  path and file name of SFTP location
- -n  notification email address
- -r  path and file name of the BI report file
- -t  report template


## Docker

Dockerfiles are included, to allow development and testing of the scripts on Windows.

These are based on a CentOS image, as it is assumed that the target environment is RedHat-based.

### Build

    docker build -t hcm-extract -f ./Dockerfile-hcm .
    docker build -t hcm-bi-extract -f ./Dockerfile-bi .

### Run

    docker run -it --rm --name hcm-extract_1 hcm-extract [PARAMETERS]
    docker run -it --rm --name hcm-bi-extract_1 hcm-bi-extract [PARAMETERS]
