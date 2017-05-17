# Oracle HCM scripts

These scripts automate the extraction and monitoring of Oracle HCM data.

- One curl call is made to trigger a data extraction
- A second curl call is repeatedly made to monitor the status of the extraction

The success of the script can be used as a trigger of a subsequent file transfer.


## Parameters

- -j  HCM job name
- -p  password
- -s  host server endpoint url (inc https)
- -u  username


## Return codes

- 00 - if the extraction completes successfully
- 05 - if the extraction does not complete before the script ends
- 09 - if the call to HCM's APIs fails
- 99 - all other errors


## Docker

A dockerfile is included, to allow development and testing of the scripts on Windows.

This is based on a CentOS image, as it is assumed that the target environment is RedHat-based.

### Build

    docker build -t hcm-scripts .

### Run

    docker run -it --rm --name hcm-scripts_1 hcm-scripts -u $username -p $password -s $server
