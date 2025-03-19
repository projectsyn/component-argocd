local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

local cluster_info_configmap =
  kube.ConfigMap('cluster-info') {
    metadata+: {
      namespace: params.namespace,
      annotations+: {
        'syn.tools/description':
          'The cluster-info config map contains a selection of Project Syn metadata associated with the cluster. All authenticated users can access this configmap.',
      },
    },
    data: {
      cluster_id: inv.parameters.cluster.name,
      tenant_id: inv.parameters.cluster.tenant,
    },
  };

local cluster_info_configmap_role = kube.Role('cluster-info-access') {
  metadata+: {
    namespace: params.namespace,
  },
  rules: [
    {
      apiGroups: [ '' ],
      resources: [ 'configmaps' ],
      resourceNames: [ cluster_info_configmap.metadata.name ],
      verbs: [ 'get' ],
    },
  ],
};

local cluster_info_configmap_rolebinding = kube.RoleBinding('cluster-info-access') {
  metadata+: {
    namespace: params.namespace,
  },
  subjects: [
    {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Group',
      name: 'system:authenticated',
    },
  ],
  roleRef_: cluster_info_configmap_role,
};

{
  configmap: cluster_info_configmap,
  rbac: [
    cluster_info_configmap_role,
    cluster_info_configmap_rolebinding,
  ],
}
