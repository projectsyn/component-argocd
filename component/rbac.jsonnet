local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

// create aggregated clusterrole for access to ArgoCD custom resources.

local custom_resources = {
  apiGroups: [ 'argoproj.io' ],
  resources: [ 'applications', 'appprojects' ],
};

local aggregated_rbac = [
  kube.ClusterRole('syn-argocd-view') {
    metadata: {
      name: 'syn-argocd-view',
      labels: {
        name: 'syn-argocd-view',
        'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
        'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
        'rbac.authorization.k8s.io/aggregate-to-view': 'true',
      },
    },
    rules: [
      custom_resources {
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
    ],
  },
  kube.ClusterRole('syn-argocd-edit') {
    metadata: {
      name: 'syn-argocd-edit',
      labels: {
        name: 'syn-argocd-edit',
        'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
        'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
      },
    },
    rules: [
      custom_resources {
        verbs: [
          'create',
          'delete',
          'deletecollection',
          'patch',
          'update',
        ],
      },
    ],
  },
];

{
  ['%s-%s' % [ obj.metadata.name, std.asciiLower(obj.kind) ]]: obj
  for obj in aggregated_rbac
}
