#!/bin/bash
CURRENT_DATE=$(date +%s)
MAX_AGE=5060160 #14 days

#just here for debugging
touch /tmp/wait
while [ -e /tmp/wait ] ; do
  sleep 5
done


for DEPLOYMENT in "$(helm list --tls | grep 'cpweb-qa')" ; do
  LAST_UPDATED=$(date --date="$(echo $DEPLOYMENT| awk '{print $3" "$4" "$5" "$6" "$7}')" +%s)
  AGE=$(( $CURRENT_DATE - $LAST_UPDATED ))
  HELM_RELEASE=$(echo $DEPLOYMENT | awk '{print $1}')
  if [[ $AGE -gt $MAX_AGE ]] ; then
    echo "Purging $HELM_RELEASE ..."
    helm del --purge "$HELM_RELEASE" --tls
  else
    echo "Skipping $HELM_RELEASE"
  fi
done
