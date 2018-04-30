#!/bin/bash

# precheck
oc whoami &> /dev/null
if [ $? -ne 0 ]; then
	echo 'Please login to a cluster before running this plugin. (e.g. oc login)'
	exit
fi

# initialize
TMP_DIR=$(mktemp -d --suffix=-openshift-sos-plugin)
DEST=$TMP_DIR/$KUBECTL_PLUGINS_CURRENT_NAMESPACE
mkdir -p $DEST

# Enable command logging
exec {BASH_XTRACEFD}>>$DEST/sos.log
set -x

# data capture
oc version &> $DEST/oc-version.txt
# Without -w, we cannot get full timestamps, so watch it and kill later
oc get event -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE -w &> $DEST/oc-get-event.txt &
WATCH_PID=$!
oc status -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE &> $DEST/oc-status.txt
oc get project -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE -o ${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT} &> $DEST/oc-get-project.${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT}
TARGET_OBJECTS="all,ds,pvc,hpa,quota,limits,sa,rolebinding,replicasets"
if [ "$KUBECTL_PLUGINS_LOCAL_FLAG_INCLUDE_CONFIGMAP" == "true" ]; then
    TARGET_OBJECTS="$TARGET_OBJECTS,cm"
fi
if [ "$KUBECTL_PLUGINS_LOCAL_FLAG_INCLUDE_SECRET" == "true" ]; then
    TARGET_OBJECTS="$TARGET_OBJECTS,secret"
fi
oc get $TARGET_OBJECTS -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE -o ${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT} &> $DEST/oc-get-all.${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT}
oc get $TARGET_OBJECTS -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE -o wide &> $DEST/oc-get-all.txt
PODS=$(oc get pod -o name -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE)
for pod in $PODS; do
  CONTAINERS=$(oc get $pod --template='{{range .spec.containers}}{{.name}} {{end}}' -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE)
  for c in $CONTAINERS; do
    oc logs $pod --container=$c --timestamps -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE &> $DEST/${pod//\//-}_${c//\//-}.log
    oc logs -p $pod --container=$c --timestamps -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE &> $DEST/${pod//\//-}_${c//\//-}.previous.log
  done
done
if [ $KUBECTL_PLUGINS_CURRENT_NAMESPACE == "openshift-infra" ]; then
  for casspod in $(oc get pods -n openshift-infra -o jsonpath='{range .items[*].metadata}{.name}{"\n"}{end}' | grep cassandra); do
    oc -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE exec $casspod -- nodetool status &> $DEST/status-$casspod.txt
    oc -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE exec $casspod -- nodetool tpstats &> $DEST/tpstats-$casspod.txt
    oc -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE exec $casspod -- nodetool proxyhistograms &> $DEST/proxyhistograms-$casspod.txt
    oc -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE exec $casspod -- nodetool tablestats hawkular_metrics &> $DEST/tablestats-hawkular_metrics-$casspod.txt
    oc -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE exec $casspod -- nodetool tablehistograms hawkular_metrics data &> $DEST/tablehistograms-hawkular_metrics-data-$casspod.txt
    oc -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE exec $casspod -- nodetool tablehistograms hawkular_metrics metrics_tags_idx &> $DEST/tablehistograms-hawkular_metrics-metrics_tags_tdx-$casspod.txt
  done
  oc get pods --all-namespaces | wc -l &> $DEST/total-number-of-pods.txt
fi
kill $WATCH_PID

# compress
DEST_FILE=/tmp/oc-sos-${KUBECTL_PLUGINS_CURRENT_NAMESPACE}-$(date +%Y%m%d-%H%M%S).tar.xz
tar caf $DEST_FILE -C $TMP_DIR $KUBECTL_PLUGINS_CURRENT_NAMESPACE

echo "Data capture complete and archived in $DEST_FILE"

# cleanup
rm -r $TMP_DIR
