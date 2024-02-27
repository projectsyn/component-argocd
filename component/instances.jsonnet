local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.argocd;

// TODO: move this to commodore.libjsonnet?
local namespacedName(name, namespace='') = {
  local namespacedName = std.splitLimit(name, '/', 1),
  local ns = if namespace != '' then namespace else error 'missing mandatory namespace in "%s"' % name,
  namespace: if std.length(namespacedName) > 1 then namespacedName[0] else ns,
  name: if std.length(namespacedName) > 1 then namespacedName[1] else namespacedName[0],
};

local ArgoCD(name) =
  local n = namespacedName(name);
  kube._Object('argoproj.io/v1beta1', 'ArgoCD', n.name) {
    metadata+: {
      namespace: n.namespace,
    },
    spec+: {
      applicationInstanceLabelKey: '%s.%s/instance' % [ n.name, n.namespace ],
    },
  };

local AppProject(name) =
  local n = namespacedName(name);
  kube._Object('argoproj.io/v1alpha1', 'AppProject', n.name) {
    metadata+: {
      namespace: n.namespace,
    },
  };

{
  '00_argocds': com.generateResources(params.argocds, ArgoCD),
  '10_approjects': com.generateResources(params.projects, AppProject),
}
