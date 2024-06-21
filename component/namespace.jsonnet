local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prometheus = import 'lib/prometheus.libsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

local ns_metadata = {
  metadata+: {
    labels+: {
               'app.kubernetes.io/part-of': 'argocd',
               'openshift.io/cluster-monitoring': 'true',
             } +
             if params.network_policies.enabled && std.member(inv.applications, 'networkpolicy') then {
               [inv.parameters.networkpolicy.labels.noDefaults]: 'true',
               [inv.parameters.networkpolicy.labels.purgeDefaults]: 'true',
             } else {},
  },
};

local namespace =
  if std.member(inv.applications, 'prometheus') then
    prometheus.RegisterNamespace(kube.Namespace(params.namespace)) + ns_metadata
  else
    kube.Namespace(params.namespace) + ns_metadata
;

{
  '00_namespace': namespace,
  [if params.monitoring.enabled then
    '20_monitoring']: import 'monitoring.libsonnet',
}
