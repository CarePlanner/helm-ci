#!/bin/bash
CURRENT_DATE=$(date +%s)
MAX_AGE=1209600 #14 days

#QA Housekeeper runs from within a pod, so we don't want the aws-iam-authenticator kubeconfig that was pre-created by the entrypoint
[ -e $HOME/.kube/config ] && rm -f $HOME/.kube/config

while read -r DEPLOYMENT ; do

  HELM_RELEASE=$(echo $DEPLOYMENT | awk '{print $1}')
  LAST_UPDATED=$(date --date="$(echo $DEPLOYMENT| awk '{print $4"T"$5$6}')" +%s)
  AGE=$(( $CURRENT_DATE - $LAST_UPDATED ))
  PR=$(echo $HELM_RELEASE | awk -F- '{print $NF}')

  # Remove deployments older than MAX_AGE
  if [[ $AGE -gt $MAX_AGE ]] ; then
    echo "Purging $HELM_RELEASE (age ${AGE}s)..."
    helm uninstall "$HELM_RELEASE" --namespace qa
    continue
  fi

  #Remove deployments with a closed PR
  if [[ $HELM_RELEASE =~ ^qa ]] && [[ ! $HELM_RELEASE =~ -release-20 ]] && [[ -n $GITHUB_OAUTH_TOKEN ]] && [[ $PR =~ ^[0-9]+$ ]] ; then
    PR_STATUS=$(curl -s -H "Authorization: token ${GITHUB_OAUTH_TOKEN}" 'https://api.github.com/repos/CarePlanner/careplanner/pulls/${PR}' | jq -r .state)
    if [[ "$PR_STATUS" == "closed" ]] ; then
      echo "Purging $HELM_RELEASE (PR ${PR} is closed)..."
      helm uninstall "$HELM_RELEASE"  --namespace qa
      continue
    fi
  fi

  echo "Skipping $HELM_RELEASE (Age: ${AGE}s)"

done <<< "$(helm list --namespace qa | grep 'cpweb-qa')"
echo "Complete."



#Permit 30 minutes of debugging
for i in {1..180} ; do
   [ "$QA_HOUSEKEEPER_DEBUG" == "1" ] || break
   sleep 10
done
