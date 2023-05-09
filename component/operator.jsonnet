local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.argocd.operator;

local image = params.images.argocd_operator;

com.Kustomization(
  params.kustomization_url,
  params.manifests_version,
  {
    'quay.io/argoprojlabs/argocd-operator': {
      newTag: image.tag,
      newName: '%(registry)s/%(repository)s' % image,
    },
  },
  params.kustomize_input,
)
