# OpenShift SOS Plugin

`openshift-sos-plugin` is an [`oc`](https://docs.openshift.org/latest/cli_reference/index.html) plugin to aid with gather information (status, logging, configuration, etc) from your OpenShift cluster. 

# Installation

1. Clone repository into your `~/.kube/plugins` directory:
```
# git clone https://github.com/bostrt/openshift-sos-plugin ~/.kube/plugins/
```
2. Ensure the plugin is available by running:
```
# oc plugin
  ...
Available Commands:
  sos         Plugin for gathering various types of data from OpenShift.
```
3. Finally, run the plugin:
```
# oc plugin sos project -n testing
Data capture complete and archived in /tmp/oc-sos-testing-2018-01-25.tar.xz
```
# Usage

After installation, you can run the plugin using the `oc` command. The prequisite is that you are logged into a cluster via the `oc` command:
```
# oc plugin sos project -n testing
Data capture complete and archived in /tmp/oc-sos-testing-2018-01-25.tar.xz
```
