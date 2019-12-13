local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = params.images.redis.image + ':' + params.images.redis.tag;

local deployment = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-deployment.yaml'));
local service = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-service.yaml'));
local objects = [
  deployment {
    spec+: {
      template+: {
        spec+: {
          volumes: [{
            name: 'data',
            emptyDir: {},
          }],
          containers: [deployment.spec.template.spec.containers[0] {
            image: image,
            imagePullPolicy: 'IfNotPresent',
            volumeMounts: [{
              name: 'data',
              mountPath: '/data',
            }],
          }],
        },
      },
    },
  },
  service,
];

{
  ['%s' % [std.asciiLower(obj.kind)]]: obj {
    metadata+: {
      namespace: params.namespace,
    },
  }
  for obj in objects
}
