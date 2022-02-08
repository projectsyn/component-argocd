local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = params.images.redis.image + ':' + params.images.redis.tag;

local deployment = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-deployment.yaml'));
local role_binding = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-rolebinding.yaml'));
local serviceaccount = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-sa.yaml'));
local service = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-service.yaml'));

local isOnOpenshift = std.startsWith(params.distribution, 'openshift');

local redisContainerSpec(image) =
  {
    image: image,
    imagePullPolicy: 'IfNotPresent',
  };

local securityContext = if isOnOpenshift then
  { securityContext:: {} }
else
  {};

local objects = [
  deployment {
    spec+: {
      template+: {
        spec+: securityContext {
          containers: [
            super.containers[0] + redisContainerSpec(image) {
              resources: params.resources.redis,
            },
          ],
        },
      },
    },
  },
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
}
