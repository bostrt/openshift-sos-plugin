#!/bin/bash

# initialize
DEST=/tmp/oc-sos/$KUBECTL_PLUGINS_CURRENT_NAMESPACE
mkdir -p $DEST

# data capture
oc get all,events -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE -o "${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT}" &> $DEST/kube-objects.${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT}
oc get all,events -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE &> $DEST/kube-objects.txt
oc status -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE &> $DEST/oc-status.txt
for i in $(oc get bc -o name -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE); do oc logs -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE --previous $i &> $DEST/${i//\//-}_previous.log; done 
for i in $(oc get bc -o name -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE); do oc logs -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE $i &> $DEST/${i//\//-}.log; done

# compress
tar caf /tmp/oc-sos-${KUBECTL_PLUGINS_CURRENT_NAMESPACE}-$(date +%F).tar.xz -C /tmp/ oc-sos/$KUBECTL_PLUGINS_CURRENT_NAMESPACE

echo "Data capture complete and archived in /tmp/oc-sos-${KUBECTL_PLUGINS_CURRENT_NAMESPACE}-$(date +%F).tar.xz"

# cleanup
rm -r $DEST

