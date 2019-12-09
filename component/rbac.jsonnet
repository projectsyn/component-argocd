local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

local controller_clusterrole = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/rbac/argocd-application-controller-clusterrole.yaml'));
local controller_clusterrolebinding = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/rbac/argocd-application-controller-clusterrolebinding.yaml'));
local server_clusterrole = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/rbac/argocd-server-clusterrole.yaml'));
local server_clusterrolebinding = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/rbac/argocd-server-clusterrolebinding.yaml'));

local objects = [
  controller_clusterrole,
  controller_clusterrolebinding {
    subjects: [controller_clusterrolebinding.subjects[0] {
      namespace: params.namespace,
    }],
  },
  server_clusterrole,
  server_clusterrolebinding {
    subjects: [server_clusterrolebinding.subjects[0] {
      namespace: params.namespace,
    }],
  },
];

{
  ['%s-%s' % [obj.metadata.name, std.asciiLower(obj.kind)]]: obj
  for obj in objects
}
