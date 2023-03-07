#!/bin/bash

echo "==> Building aro workshop on OpenShift"
oc new-project workshop
oc new-build --name aro --binary --strategy source --image quay.io/openshift-examples/ubi8-s2i-mkdocs
oc start-build aro --from-dir . --follow

echo "==> Deploying ARO workshop to OpenShift"
oc new-app aro
oc create route edge --service=aro

ROUTE=$(oc get route aro -o jsonpath='{"https://"}{.status.ingress[0].host}{"\n"}')

echo "==> Done"
echo ""
echo "Workshop can be found at ${ROUTE}"

