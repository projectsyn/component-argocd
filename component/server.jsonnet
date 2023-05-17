local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = '%(registry)s/%(repository)s:%(tag)s' % params.images.argocd;
local common = import 'common.libsonnet';
local loadManifest = common.loadManifest;

local deployment = loadManifest('server/argocd-server-deployment.yaml');
local role = loadManifest('server/argocd-server-role.yaml');
local role_binding = loadManifest('server/argocd-server-rolebinding.yaml');
local serviceaccount = loadManifest('server/argocd-server-sa.yaml');
local service = loadManifest('server/argocd-server-service.yaml');
local metrics_svc = loadManifest('server/argocd-server-metrics.yaml') {
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
              '--loglevel',
              common.evaluate_log_level('server'),
              '--logformat',
              common.evaluate_log_format('server'),
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
