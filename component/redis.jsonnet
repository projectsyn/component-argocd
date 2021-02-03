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
local objects = [
  deployment {
    spec+: {
      template+: {
        spec+: {
          [if std.startsWith(inv.parameters.facts.distribution, 'openshift') then
            'securityContext']:: {},
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
  role,
  role_binding,
  serviceaccount,
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
