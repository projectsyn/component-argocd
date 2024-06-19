local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.argocd;
local isOpenshift = std.member([ 'openshift4', 'oke' ], params.distribution);

[
  kube.NetworkPolicy('argocd-allow-same-namespace') {
    spec: {
      ingress: [
        {
          from: [
            {
              podSelector: {},
            },
          ],
        },
      ],
      policyTypes: [
        'Ingress',
      ],
      podSelector: {},
    },
  },
  kube.NetworkPolicy('argocd-allow-operator') {
    spec: {
      ingress: [
        {
          from: [
            {
              namespaceSelector: {
                matchLabels: {
                  'kubernetes.io/metadata.name': params.operator.namespace,
                },
              },
            },
          ],
        },
      ],
      policyTypes: [
        'Ingress',
      ],
      podSelector: {},
    },
  },
]
+ (if isOpenshift then [
     kube.NetworkPolicy('argocd-allow-openshift-monitoring') {
       spec: {
         // from https://kubernetes.io/docs/concepts/services-networking/network-policies/#allow-all-ingress-traffic
         ingress: [
           {
             from: [
               {
                 namespaceSelector: {
                   matchLabels: {
                     'network.openshift.io/policy-group': 'monitoring',
                   },
                 },
               },
             ],
           },
         ],
         policyTypes: [
           'Ingress',
         ],
         podSelector: {},
       },
     },
   ] else [])
+ (if std.length(params.network_policies.allow_from_namespaces) > 0 then [
     kube.NetworkPolicy('argocd-allow-whitelisted-namespaces') {
       spec: {
         ingress: [
           {
             from: [
               {
                 namespaceSelector: {
                   matchLabels: {
                     'kubernetes.io/metadata.name': namespace,
                   },
                 },
               },
             ],
           }
           for namespace in params.network_policies.allow_from_namespaces
         ],
         policyTypes: [
           'Ingress',
         ],
         podSelector: {},
       },
     },
   ] else [])
