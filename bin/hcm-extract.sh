#!/bin/bash

# Oracle HCM data extract script
# Run with -h parameter for usage


# configuration stuff ----------------

_DEBUG="off"
SCRIPTDIR=$(dirname $0)
SCRIPTNAME=$(basename $0)
LOGDIR="/tmp/${SCRIPTNAME}/log"
HEADERS="Content-Type:text/xml;charset=UTF-8"
REQUEST_FILE=${SCRIPTDIR}/../cfg/submitFlow.xml
CONNECT_TIMEOUT=120
MAX_TIME=3600
URL_PATH="hcmProcFlowCoreController/FlowActionsService"

POLL_INTERVAL=5
POLL_COUNT=5

RC_SUCCESS=0
RC_USAGE=1
RC_TIMEOUT=5
RC_HTTP_ERROR=9
RC_GENERAL_ERROR=99


# commands used ----------------------




# functions --------------------------


usage ()
{
  echo "$0 [-h] -- Oracle HCM data extract script

where
    -h  show this help message
    -p  password
    -u  username"

  exit ${RC_USAGE}
}


call_hcm ()
{
  USER_AUTH="${USERNAME}:${PASSWORD}"
  URL="${HOST_SERVER}/${URL_PATH}"
  OUTPUT="${LOGDIR}/${SCRIPTNAME}_$(date +%Y%m%d%H%M%S).gz"

  log "Calling ${URL}"
  log "Output file is ${OUTPUT}"

  mkdir -p ${LOGDIR} >/dev/null 2>&1

  # set up the curl command
  CURL="curl -w %{http_code} --silent --user ${USER_AUTH} --header ${HEADERS} -o ${OUTPUT} --data @${REQUEST_FILE} --connect-time ${CONNECT_TIMEOUT} --max-time ${MAX_TIME} ${URL}"

  # run the curl command, which returns the response code
  HTTP_RESPONSE=$(${CURL})

  log "HTTP response code ${HTTP_RESPONSE}"

  if [[ ${HTTP_RESPONSE} == 200 ]]; then
      log "Successful call"
  else
      log "ERROR - SOAP output follows"
      gunzip -c ${OUTPUT}
      exit ${RC_HTTP_ERROR}
  fi
}


log ()
{
  TIMESTAMP=`date "+%Y-%m-%d %H:%M.%S"`
  echo $0 ${TIMESTAMP} $1
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
while getopts ":p:s:u:" opt; do
  case ${opt} in
    p)
      PASSWORD=${OPTARG}
      ;;
    s)
      HOST_SERVER=${OPTARG}
      ;;
    u)
      USERNAME=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z "${PASSWORD}" ] || [ -z "${HOST_SERVER}" ] || [ -z "${USERNAME}" ]; then
    usage
fi

log "Started"

call_hcm

COUNTER=0
while [  ${COUNTER} -lt ${POLL_COUNT} ]; do
  sleep ${POLL_INTERVAL}
  echo The counter is ${COUNTER}
  let COUNTER=COUNTER+1
done

log "Finished"

DEBUG set +x
exit ${RC_SUCCESS}
