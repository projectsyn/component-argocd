local com = import 'lib/commodore.libjsonnet';

local inv = com.inventory();
local params = inv.parameters.argocd.operator;

local file_apiext_argocd = com.yaml_load(std.extVar('output_path') + '/apiextensions.k8s.io_v1_customresourcedefinition_argocds.argoproj.io.yaml');
local file_deployment = com.yaml_load(std.extVar('output_path') + '/apps_v1_deployment_syn-argocd-operator-controller-manager.yaml');

{
  'apiextensions.k8s.io_v1_customresourcedefinition_argocds.argoproj.io': file_apiext_argocd {
    metadata+: {
      creationTimestamp: null,
      annotations+: {
        [if params.conversion_webhook then 'cert-manager.io/inject-ca-from']: params.namespace + '/serving-cert',
      },
    },
    spec+: {
      [if !params.conversion_webhook then 'conversion']: { strategy: 'None' },
    },
  },
  'apps_v1_deployment_syn-argocd-operator-controller-manager': file_deployment {
    spec+: {
      template+: {
        spec+: {
          volumes: [ { name: 'cert', emptyDir: {} } ],
        },
      },
    },
  },
}
