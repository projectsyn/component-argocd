local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = params.images.argocd.image + ':' + params.images.argocd.tag;

local deployment = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/server/argocd-server-deployment.yaml'));
local role = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/server/argocd-server-role.yaml'));
local role_binding = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/server/argocd-server-rolebinding.yaml'));
local serviceaccount = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/server/argocd-server-sa.yaml'));
local service = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/server/argocd-server-service.yaml'));
local metrics_svc = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/server/argocd-server-metrics.yaml')) {
  metadata+: {
    namespace: params.namespace,
  },
};

local objects = [
  deployment {
    spec+: {
      template+: {
        spec+: {
          containers: [ deployment.spec.template.spec.containers[0] {
            image: image,
            imagePullPolicy: 'IfNotPresent',
            command: [
              'argocd-server',
              '--staticassets',
              '/shared/app',
              '--insecure',
            ],
            [if params.resources.server != null then 'resources']:
              std.prune(params.resources.server),
          } ] + deployment.spec.template.spec.containers[1:],
        },
      },
    },
  },
  role,
  role_binding,
  serviceaccount,
  service,
];

{
  ['%s' % [ std.asciiLower(obj.kind) ]]: obj {
    metadata+: {
      namespace: params.namespace,
    },
  }
  for obj in objects
} + { 'metrics-service': metrics_svc }
