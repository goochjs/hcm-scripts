#!/bin/bash

# Oracle HCM data extract script
# Run with -h parameter for usage


# configuration stuff ----------------

_DEBUG="off"

## script settings
SCRIPTDIR=$(dirname $0)
SCRIPTNAME=$(basename $0)

## curl control
REQUEST_DIR="/tmp/${SCRIPTNAME}/request"
RESPONSE_DIR="/tmp/${SCRIPTNAME}/response"
SUBMIT_FILE_ORIG=${SCRIPTDIR}/../cfg/hcm-submit.xml
SUBMIT_FILE=${REQUEST_DIR}/hcm-submit_$(date +%Y%m%d%H%M%S).xml
STATUS_FILE_ORIG=${SCRIPTDIR}/../cfg/hcm-status.xml
STATUS_FILE=${REQUEST_DIR}/hcm-status_$(date +%Y%m%d%H%M%S).xml
CONNECT_TIMEOUT=5
MAX_TIME=30
URL_PATH="hcmProcFlowCoreController/FlowActionsService"
HEADERS="Content-Type:text/xml;charset=UTF-8"

## request file configuration literals
## these strings are in ${SUBMIT_FILE_ORIG} and ${STATUS_FILE_ORIG}
LIT_JOBNAME="JOBNAME"
LIT_DATESTAMP="DATESTAMP"
LIT_TIMESTAMP="TIMESTAMP"
## these are the strings to be searched for in the HTTP responses
LIT_COMPLETE="COMPLETED"

## return codes
RC_SUCCESS=0
RC_USAGE=1
RC_TIMEOUT=5
RC_HTTP_ERROR=9
RC_GENERAL_ERROR=99


# functions --------------------------


usage ()
{
  echo "$0 [params] -- Oracle HCM data extract script

  - One curl call is made to trigger a data extraction
  - A second curl call is repeatedly made to monitor the status of the extraction

  The success of the script can be used as a trigger of a subsequent file transfer.

params are
    -h  show this help message
    -j  HCM job name
    -l  number of times to poll when checking status
    -p  password
    -s  host server endpoint url (inc https)
    -u  username
    -w  wait time (in seconds) between status checks"

  exit ${RC_USAGE}
}


prepare_config_file ()
{
  # Take the original configuration file and add the appropriate date, time and job name
  # This function takes three parameters
  #    1 = whether it is the submission or the status job that's being configured
  #    2 = the original config file (which contains literals in need of substitution)
  #    3 = the output file into which config will be written with literals substituted
  # The output file will be fed to HCM

  if [ ! -f ${2} ]; then
      log "${1} configuration file ${2} not found!"
      exit ${RC_GENERAL_ERROR}
  fi

  log "Original ${1} configuration file ${2}"

  mkdir -p ${REQUEST_DIR} >/dev/null 2>&1
  cp ${2} ${3}

  find_replace "${LIT_JOBNAME}" "${JOBNAME}" "${3}"
  find_replace "${LIT_DATESTAMP}" $(date +%Y-%m-%d) "${3}"
  find_replace "${LIT_TIMESTAMP}" $(date +%H%M%S) "${3}"
}


find_replace ()
{
    # Take two strings and a file as parameters
    # Replace all instances of the first string in the file with the second string

    TMP=$(mktemp)
    sed "s|${1}|${2}|g" ${3} > ${TMP} && mv ${TMP} ${3}
    rm ${TMP} 2> /dev/null
}


call_hcm ()
{
  # Call the HCM web service
  # This function takes two parameters
  #    1 = an input file to put into the HTTP request
  #    2 = the output file into which the HTTP response will be written

  USER_AUTH="${USERNAME}:${PASSWORD}"
  URL="${HOST_SERVER}/${URL_PATH}"

  log "Request file ${1}"
  log "Response file ${2}"
  log "Calling ${URL}"

  if [ ! -f ${1} ]; then
      log "Request file not found ${1}"
      exit ${RC_GENERAL_ERROR}
  fi

  # set up the curl command
  CURL="curl -w %{http_code} --silent --user ${USER_AUTH} --header ${HEADERS} -o ${2} --data @${1} --connect-time ${CONNECT_TIMEOUT} --max-time ${MAX_TIME} ${URL}"

  # run the curl command, which returns the response code
  HTTP_RESPONSE=$(${CURL})

  if [[ ${HTTP_RESPONSE} == 200 ]]; then
      log "Successful call (${HTTP_RESPONSE})"
  else
      log "HTTP response code ${HTTP_RESPONSE}"
      log "ERROR - SOAP request follows"
      cat ${1}
      log "ERROR - SOAP response follows"
      gunzip -c ${2}
      exit ${RC_HTTP_ERROR}
  fi
}


log ()
{
  LOGTIMESTAMP=`date "+%Y-%m-%d %H:%M.%S"`
  echo $0 ${LOGTIMESTAMP} $1
}


function DEBUG()
{
 [ "${_DEBUG}" == "on" ] &&  $@
}




# start of main ----------------------

DEBUG set -x

# stop if no params have been passed
if [ $# -eq 0 ] ; then
  usage
  exit 1
fi

# check command line params,
while getopts ":j:l:p:s:u:w:" opt; do
  case ${opt} in
    j)
      JOBNAME=${OPTARG}
    ;;
    l)
      POLL_COUNT=${OPTARG}
    ;;
    p)
      PASSWORD=${OPTARG}
    ;;
    s)
      HOST_SERVER=${OPTARG}
    ;;
    u)
      USERNAME=${OPTARG}
    ;;
    w)
      POLL_INTERVAL=${OPTARG}
    ;;
    *)
      usage
    ;;
  esac
done

if  [ -z "${JOBNAME}" ] || \
    [ -z "${POLL_COUNT}" ] || \
    [ -z "${PASSWORD}" ] || \
    [ -z "${HOST_SERVER}" ] || \
    [ -z "${USERNAME}" ] || \
    [ -z "${POLL_INTERVAL}" ]; then
    usage
fi

if  [[ ! ${POLL_COUNT} =~ ^-?[0-9]+$ ]] || \
    [[ ! ${POLL_INTERVAL} =~ ^-?[0-9]+$ ]]; then

    echo "Wait time (-w) and loop count (-l) must be integers"
    exit ${RC_USAGE}
fi

log "${JOBNAME} started"

# prepare submission and status config files
prepare_config_file submit ${SUBMIT_FILE_ORIG} ${SUBMIT_FILE}
prepare_config_file status ${STATUS_FILE_ORIG} ${STATUS_FILE}

mkdir -p ${RESPONSE_DIR} >/dev/null 2>&1

# submit the HCM job
RESPONSE_FILE=${RESPONSE_DIR}/${SCRIPTNAME}_submit_$(date +%Y%m%d%H%M%S).gz
call_hcm ${SUBMIT_FILE} ${RESPONSE_FILE}

# call the HCM status job repeatedly, exiting if complete
COUNTER=1
while [ ${COUNTER} -le ${POLL_COUNT} ]; do
  log "Waiting ${POLL_INTERVAL} seconds..."
  sleep ${POLL_INTERVAL}
  log "Status check: ${COUNTER} of ${POLL_COUNT}"

  RESPONSE_FILE=${RESPONSE_DIR}/${SCRIPTNAME}_status_$(date +%Y%m%d%H%M%S).gz
  call_hcm ${STATUS_FILE} ${RESPONSE_FILE}

  if grep -q ${LIT_COMPLETE} "${RESPONSE_FILE}"; then
     log "Job ${JOBNAME} successfully completed"
     exit ${RC_SUCCESS}
  fi

  log "${JOBNAME} not yet complete"
  let COUNTER=COUNTER+1
done

log "ERROR - last SOAP response follows"
cat ${RESPONSE_FILE}
log "${JOBNAME} did not complete before timeout"

DEBUG set +x
exit ${RC_TIMEOUT}
