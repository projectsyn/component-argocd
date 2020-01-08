local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = params.images.argocd.image + ':' + params.images.argocd.tag;

local deployment = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/repo-server/argocd-repo-server-deployment.yaml'));
local service = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/repo-server/argocd-repo-server-service.yaml'));
local objects = [
  deployment {
    spec+: {
      template+: {
        spec+: {
          containers: [deployment.spec.template.spec.containers[0] {
            image: image,
            imagePullPolicy: 'IfNotPresent',
            env+: [
              {
                name: 'VAULT_USERNAME',
                value: inv.parameters.customer.name + '-' + inv.parameters.cluster.name,
              },
              {
                name: 'VAULT_PASSWORD',
                valueFrom: {
                  secretKeyRef: {
                    name: 'steward',
                    key: 'token',
                  },
                },
              },
            ],
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
