local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = params.images.redis.image + ':' + params.images.redis.tag;

local deployment = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-deployment.yaml'));
local role = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-role.yaml'));
local role_binding = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-rolebinding.yaml'));
local serviceaccount = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-sa.yaml'));
local service = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/redis/argocd-redis-service.yaml'));


local redisSpec(image) =
  local strContains(s, substr) = std.findSubstr(substr, s) != [];

  local volumeMounts(path) = [ {
    name: 'data',
    mountPath: path,
  } ];

  {
    image: image,
    imagePullPolicy: 'IfNotPresent',
  } +
  if strContains(image, 'bitnami') then
    {
      env+: [
        { name: 'ALLOW_EMPTY_PASSWORD', value: 'yes' },
        { name: 'REDIS_AOF_ENABLED', value: 'no' },
        { name: 'REDIS_EXTRA_FLAGS', value: "--save ''" },
      ],
      args: [],
      volumeMounts: volumeMounts('/bitnami/redis/data'),
    }
  else
    {
      volumeMounts: volumeMounts('/data'),
    };

local objects = [
  deployment {
    spec+: {
      template+: {
        spec+: {
          securityContext:: {},
          volumes: [ {
            name: 'data',
            emptyDir: {},
          } ],
          containers: [
            deployment.spec.template.spec.containers[0] + redisSpec(image),
          ],
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
}
