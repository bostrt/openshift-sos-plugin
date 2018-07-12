#!/bin/bash

# vars
RED='\e[31m'
GREEN='\e[32m'
RESET='\e[0m'
OC_CMD="oc -n $KUBECTL_PLUGINS_CURRENT_NAMESPACE"

# precheck
oc whoami &> /dev/null
if [ $? -ne 0 ]; then
	echo -e "${RED}Please login to a cluster before running this plugin. (e.g. oc login)${RESET}"
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
# Without -w, we cannot get full timestamps, so watch it with timeout command
timeout 15 $OC_CMD get event -w &> $DEST/oc-get-event.txt
$OC_CMD status &> $DEST/oc-status.txt
$OC_CMD get project -o ${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT} &> $DEST/oc-get-project.${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT}
TARGET_OBJECTS="all,ds,pvc,hpa,quota,limits,sa,rolebinding,replicasets"
if [ "$KUBECTL_PLUGINS_LOCAL_FLAG_INCLUDE_CONFIGMAP" == "true" ]; then
    TARGET_OBJECTS="$TARGET_OBJECTS,cm"
fi
if [ "$KUBECTL_PLUGINS_LOCAL_FLAG_INCLUDE_SECRET" == "true" ]; then
    TARGET_OBJECTS="$TARGET_OBJECTS,secret"
fi
$OC_CMD get $TARGET_OBJECTS -o ${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT} &> $DEST/oc-get-all.${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT}
$OC_CMD get $TARGET_OBJECTS -o wide &> $DEST/oc-get-all.txt
PODS=$($OC_CMD get pod -o name)
for pod in $PODS; do
  CONTAINERS=$($OC_CMD get $pod --template='{{range .spec.containers}}{{.name}} {{end}}')
  for c in $CONTAINERS; do
    $OC_CMD logs    $pod --container=$c --timestamps &> $DEST/${pod//\//-}_${c//\//-}.log
    $OC_CMD logs -p $pod --container=$c --timestamps &> $DEST/${pod//\//-}_${c//\//-}.previous.log
  done
done

# non-namespaced objects
oc get storageclass -o wide &> $DEST/oc-get-storageclass.txt
oc get storageclass -o ${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT} &> $DEST/oc-get-storageclass.${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT}

# openshift-infra
if [ $KUBECTL_PLUGINS_CURRENT_NAMESPACE == "openshift-infra" ]; then
  for casspod in $($OC_CMD get pods -o jsonpath='{range .items[*].metadata}{.name}{"\n"}{end}' | grep cassandra); do
    $OC_CMD exec $casspod -- nodetool status &> $DEST/status-$casspod.txt
    $OC_CMD exec $casspod -- nodetool tpstats &> $DEST/tpstats-$casspod.txt
    $OC_CMD exec $casspod -- nodetool proxyhistograms &> $DEST/proxyhistograms-$casspod.txt
    $OC_CMD exec $casspod -- nodetool tablestats hawkular_metrics &> $DEST/tablestats-hawkular_metrics-$casspod.txt
    $OC_CMD exec $casspod -- nodetool tablehistograms hawkular_metrics data &> $DEST/tablehistograms-hawkular_metrics-data-$casspod.txt
    $OC_CMD exec $casspod -- nodetool tablehistograms hawkular_metrics metrics_tags_idx &> $DEST/tablehistograms-hawkular_metrics-metrics_tags_tdx-$casspod.txt
  done
fi

# cluster-admin level objects
if [ "$KUBECTL_PLUGINS_LOCAL_FLAG_INCLUDE_ADMIN" == "true" ]; then
  if [ "$(oc auth can-i get pods -n default)" == "yes" ]; then
    oc get pods -o wide --all-namespaces &> $DEST/all-pods.txt
    cat $DEST/all-pods.txt | wc -l &> $DEST/total-number-of-pods.txt
  fi
  if [ "$(oc auth can-i get nodes)" == "yes" ]; then
    oc get node -o wide --show-labels &> $DEST/oc-get-node.txt
    oc get node -o ${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT} &> $DEST/oc-get-node.${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT}
    oc describe node &> $DEST/oc-describe-node.txt
  fi
  if [ "$(oc auth can-i get hostsubnet)" == "yes" ]; then
    oc get hostsubnet &> $DEST/oc-get-hostsubnet.txt
  fi
  if [ "$(oc auth can-i get clusterrolebinding)" == "yes" ]; then
    oc get clusterrolebinding &> $DEST/oc-get-clusterrolebinding.txt
  fi
  if [ "$(oc auth can-i get pv)" == "yes" ]; then
    oc get pv &> $DEST/oc-get-clusterrolebinding.txt
    oc get pv -o ${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT} &> $DEST/oc-get-clusterrolebinding.${KUBECTL_PLUGINS_LOCAL_FLAG_OUTPUT}
  fi
fi

# compress
DEST_FILE=/tmp/oc-sos-${KUBECTL_PLUGINS_CURRENT_NAMESPACE}-$(date +%Y%m%d-%H%M%S).tar.xz
tar caf $DEST_FILE -C $TMP_DIR $KUBECTL_PLUGINS_CURRENT_NAMESPACE

echo -e "${GREEN}Data capture complete and archived in ${DEST_FILE}${RESET}"

# cleanup
rm -r $TMP_DIR
