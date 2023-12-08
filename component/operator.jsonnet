local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.argocd.operator;

local image = params.images.argocd_operator;
local rbac = params.images.kube_rbac_proxy;

local kustomize_input = params.kustomize_input {
  patches+: [
    if std.length(params.cluster_scope_namespaces) > 0 then {
      patch: std.format(|||
        - op: add
          path: "/spec/template/spec/containers/1/env/-"
          value:
            name: "ARGOCD_CLUSTER_CONFIG_NAMESPACES"
            value: "%s"
      |||, std.join(',', params.cluster_scope_namespaces)),
      target: {
        kind: 'Deployment',
        name: 'argocd-operator-controller-manager',
      },
    },
    {
      patch: |||
        - op: add
          path: "/spec/template/spec/containers/1/env/-"
          value:
            name: "ENABLE_CONVERSION_WEBHOOK"
            value: "true"
      |||,
      target: {
        kind: 'Deployment',
        name: 'argocd-operator-controller-manager',
      },
    },
  ],
};

com.Kustomization(
  params.kustomization_url,
  params.manifests_version,
  {
    'quay.io/argoprojlabs/argocd-operator': {
      newTag: image.tag,
      newName: '%(registry)s/%(repository)s' % image,
    },
    'gcr.io/kubebuilder/kube-rbac-proxy': {
      newTag: rbac.tag,
      newName: '%(registry)s/%(repository)s' % rbac,
    },
  },
  kustomize_input,
)
