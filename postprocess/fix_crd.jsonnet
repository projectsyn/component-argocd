local com = import 'lib/commodore.libjsonnet';

local inv = com.inventory();
local params = inv.parameters.argocd.operator;

local file_apiext_argocd = com.yaml_load(std.extVar('output_path') + '/apiextensions.k8s.io_v1_customresourcedefinition_argocds.argoproj.io.yaml');

{
  'apiextensions.k8s.io_v1_customresourcedefinition_argocds.argoproj.io': file_apiext_argocd {
    metadata+: {
      creationTimestamp: null,
      annotations+: {
        'cert-manager.io/inject-ca-from': params.namespace + '/serving-cert',
      },
    },
  },
}
