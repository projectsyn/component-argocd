local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = params.images.argocd.image + ':' + params.images.argocd.tag;

local deployment = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/application-controller/argocd-application-controller-deployment.yaml'));
local role = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/application-controller/argocd-application-controller-role.yaml'));
local role_binding = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/application-controller/argocd-application-controller-rolebinding.yaml'));
local serviceaccount = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/application-controller/argocd-application-controller-sa.yaml'));
local metrics_svc = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/application-controller/argocd-metrics.yaml'));

local objects = [
  deployment {
    spec+: {
      template+: {
        spec+: {
          containers: [deployment.spec.template.spec.containers[0] {
            image: image,
            imagePullPolicy: 'IfNotPresent',
            command: [
              'argocd-application-controller',
              '--status-processors',
              '20',
              '--operation-processors',
              '10',
              '--app-resync',
              '10',
            ],
          }],
        },
      },
    },
  },
  role,
  role_binding,
  serviceaccount,
  metrics_svc,
];

{
  ['%s' % [std.asciiLower(obj.kind)]]: obj {
    metadata+: {
      namespace: params.namespace,
    },
  }
  for obj in objects
}
