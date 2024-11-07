local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prometheus = import 'lib/prometheus.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.argocd;
local isOpenshift = std.member([ 'openshift4', 'oke' ], params.distribution);

local policy(name, spec) = {
  apiVersion: 'cilium.io/v2',
  kind: 'CiliumNetworkPolicy',
  metadata: {
    name: name,
  },
  spec: spec,
};

[
  policy(name, params.cilium_network_policies[name])
  for name in std.objectFields(params.cilium_network_policies)
]
