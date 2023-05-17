local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local loadManifest = (import 'common.libsonnet').loadManifest;

local controller_clusterrole = loadManifest('rbac/argocd-application-controller-clusterrole.yaml');
local controller_clusterrolebinding = loadManifest('rbac/argocd-application-controller-clusterrolebinding.yaml');
local server_clusterrole = loadManifest('rbac/argocd-server-clusterrole.yaml');
local server_clusterrolebinding = loadManifest('rbac/argocd-server-clusterrolebinding.yaml');

local patch_name(obj) =
  obj {
    metadata+: {
      name: 'syn-%s' % super.name,
    },
  };

// For roles we only need to patch the name.
local patch_role = patch_name;

// For rolebindings we need to patch the object name, subject namespace and
// role name.
local patch_rolebinding(obj) =
  patch_name(obj) {
    subjects: [ super.subjects[0] {
      namespace: params.namespace,
    } ],
    roleRef+: {
      name: 'syn-%s' % super.name,
    },
  };

local objects = [
  patch_role(controller_clusterrole),
  patch_rolebinding(controller_clusterrolebinding),
  patch_role(server_clusterrole),
  patch_rolebinding(server_clusterrolebinding),
];

// create aggregated clusterrole for access to ArgoCD custom resources.

local custom_resources = {
  apiGroups: [ 'argoproj.io' ],
  resources: [ 'applications', 'appprojects' ],
};

local aggregated_rbac = [
  kube.ClusterRole('syn-argocd-view') {
    metadata+: {
      labels+: {
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
    metadata+: {
      labels+: {
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
  for obj in objects + aggregated_rbac
}
