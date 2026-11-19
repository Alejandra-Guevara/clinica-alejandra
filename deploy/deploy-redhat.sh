#!/usr/bin/env bash
# Una sola compilación y un solo Deployment para React y Express.
set -euo pipefail
project=maria-guevara-rio-dev
app=clinica-alejandra
manifest=https://raw.githubusercontent.com/Alejandra-Guevara/clinica-alejandra/main/deploy/openshift.yaml
oc whoami >/dev/null
oc project "$project" >/dev/null
if oc get ksvc "$app" -n "$project" >/dev/null 2>&1; then
  printf 'Ya existe un servicio Serverless con ese nombre. Usa su URL o un nombre de Deployment distinto para evitar una Route duplicada.\n' >&2
  exit 1
fi
oc apply -n "$project" -f "$manifest"
oc start-build "$app" -n "$project" --follow --wait
image=$(oc get istag "$app:latest" -n "$project" -o jsonpath='{.image.dockerImageReference}')
if [[ "$image" != *@sha256:* ]]; then
  printf 'No se encontró una imagen construida válida.\n' >&2
  exit 1
fi
oc set image deployment/"$app" -n "$project" "clinica=$image"
oc rollout status deployment/"$app" -n "$project" --timeout=240s
host=$(oc get route "$app" -n "$project" -o jsonpath='{.spec.host}')
printf '\nAplicación completa: https://%s\n' "$host"
curl --fail --show-error --silent --retry 5 --retry-delay 2 --max-time 20 "https://$host/health"
printf '\nEstado de MySQL:\n'
if ! curl --fail-with-body --show-error --silent --max-time 20 "https://$host/api/health"; then
  printf '\nLa página y Express están disponibles. Revisa la cuenta/esquema de MySQL en backend/src/config/demo.js.\n' >&2
  exit 1
fi
printf '\n'
