local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = '%(registry)s/%(repository)s:%(tag)s' % params.images.redis;
local loadManifest = (import 'common.libsonnet').loadManifest;

local deployment = loadManifest('redis/argocd-redis-deployment.yaml');
local role_binding = loadManifest('redis/argocd-redis-rolebinding.yaml');
local serviceaccount = loadManifest('redis/argocd-redis-sa.yaml');
local service = loadManifest('redis/argocd-redis-service.yaml');

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
              [if params.resources.redis != null then 'resources']:
                std.prune(params.resources.redis),
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
