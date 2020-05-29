# Helm3 compatibility
#  Currently (May 2020) all our pipelines use helm2 with the '--tls' switch which
#  is deprecated in helm3. So we'll strip it out if the command is 'helm', this
#  allows us to jump straight to helm3 without modifying the circleci configs in
#  every repo

for i in $@ ; do
  [[ "$i" != "--tls" ]] && ARGS+=("$i")
done

exec /usr/bin/helm3 "${ARGS[@]}"
