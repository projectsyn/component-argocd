local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = params.images.argocd.image + ':' + params.images.argocd.tag;
local loadManifest = (import 'common.libsonnet').loadManifest;

local statefulset = loadManifest('application-controller/argocd-application-controller-statefulset.yaml');
local role = loadManifest('application-controller/argocd-application-controller-role.yaml');
local role_binding = loadManifest('application-controller/argocd-application-controller-rolebinding.yaml');
local serviceaccount = loadManifest('application-controller/argocd-application-controller-sa.yaml');
local metrics_svc = loadManifest('application-controller/argocd-metrics.yaml');

local objects = [
  statefulset {
    spec+: {
      template+: {
        spec+: {
          containers: [ statefulset.spec.template.spec.containers[0] {
            image: image,
            imagePullPolicy: 'IfNotPresent',
            command: [
              'argocd-application-controller',
              '--status-processors',
              '20',
              '--operation-processors',
              '10',
              '--app-resync',
              std.format('%d', params.resync_seconds),
            ],
            [if params.resources.application_controller != null then 'resources']:
              std.prune(params.resources.application_controller),
          } ],
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
  ['%s' % [ std.asciiLower(obj.kind) ]]: obj {
    metadata+: {
      namespace: params.namespace,
    },
  }
  for obj in objects
}
