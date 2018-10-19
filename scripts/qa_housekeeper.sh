#!/bin/bash
CURRENT_DATE=$(date +%s)
MAX_AGE=1209600 #14 days

while read -r DEPLOYMENT ; do
  LAST_UPDATED=$(date --date="$(echo $DEPLOYMENT| awk '{print $3" "$4" "$5" "$6" "$7}')" +%s)
  AGE=$(( $CURRENT_DATE - $LAST_UPDATED ))
  HELM_RELEASE=$(echo $DEPLOYMENT | awk '{print $1}')
  if [[ $AGE -gt $MAX_AGE ]] ; then
    echo "Purging $HELM_RELEASE (age ${AGE}s)..."
    helm del --purge "$HELM_RELEASE" --tls
  else
    echo "Skipping $HELM_RELEASE (age ${AGE}s)"
  fi
done <<< "$(helm list --tls | grep 'cpweb-qa')"
echo "Complete."

#Permit 30 minutes of debugging
for i in {1..180} ; do 
   [ "$QA_HOUSEKEEPER_DEBUG" == "1" ] || break
   sleep 10
done

