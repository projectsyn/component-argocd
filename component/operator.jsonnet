local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.argocd.operator;

local image = params.images.argocd_operator;
local rbac = params.images.kube_rbac_proxy;

local skip(var) =
  var == 'ARGOCD_CLUSTER_CONFIG_NAMESPACES';

local kustomize_patch_scopens = if std.length(params.cluster_scope_namespaces) > 0 then {
  patches+: [
    {
      patch: std.manifestYamlDoc([
        {
          op: 'add',
          path: '/spec/template/spec/containers/1/env/-',
          value: {
            name: 'ARGOCD_CLUSTER_CONFIG_NAMESPACES',
            value: std.join(',', params.cluster_scope_namespaces),
          },
        },
      ] + [
        {
          op: 'add',
          path: '/spec/template/spec/containers/1/env/-',
          value: {
            name: envvar,
            value: params.env[envvar],
          },
        }
        for envvar in std.objectFields(params.env)
        if !skip(envvar)
      ]),
      target: {
        kind: 'Deployment',
        name: 'argocd-operator-controller-manager',
      },
    },
  ],
} else {};

local kustomize_patch_conversion = if params.conversion_webhook then {
  patches+: [
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
} else {};

local kustomize_patch_priorityclass = {
  patches+: [
    {
      patch: |||
        - op: add
          path: "/spec/template/spec/priorityClassName"
          value: %(priorityclass)s
      ||| % params.priority_class,
      target: {
        kind: 'Deployment',
        name: 'argocd-operator-controller-manager',
      },
    },
  ],
};
local kustomize_input = params.kustomize_input
                        + kustomize_patch_scopens
                        + kustomize_patch_conversion
                        + kustomize_patch_priorityclass;

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
    'quay.io/brancz/kube-rbac-proxy': {
      newTag: rbac.tag,
      newName: '%(registry)s/%(repository)s' % rbac,
    },
  },
  kustomize_input,
)
