local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

local controller_clusterrole = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/rbac/argocd-application-controller-clusterrole.yaml'));
local controller_clusterrolebinding = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/rbac/argocd-application-controller-clusterrolebinding.yaml'));
local server_clusterrole = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/rbac/argocd-server-clusterrole.yaml'));
local server_clusterrolebinding = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/rbac/argocd-server-clusterrolebinding.yaml'));

local legacy_objects = [
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

local patch_name(obj) =
  obj {
    metadata+: {
      name: 'syn-%s' % super.name,
    },
  };

// For roles we only need to patch the name.
local patch_role = patch_name;

// For rolebindings we need to patch the object name, subject namespace and
// role name.
local patch_rolebinding(obj) =
  patch_name(obj) {
    subjects: [super.subjects[0] {
      namespace: params.namespace,
    }],
    roleRef+: {
      name: 'syn-%s' % super.name,
    },
  };

local objects = [
  patch_role(controller_clusterrole),
  patch_rolebinding(controller_clusterrolebinding),
  patch_role(server_clusterrole),
  patch_rolebinding(server_clusterrolebinding),
];

{
  ['%s-%s' % [obj.metadata.name, std.asciiLower(obj.kind)]]: obj
  for obj in (legacy_objects + objects)
}
