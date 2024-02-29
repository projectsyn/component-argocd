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

// Remove nulled instances
//
// Do NOT use `std.prune` as this removes all empty fields (`{}`, `[]`) as well
local instances = {
  [k]: params.instances[k]
  for k in std.objectFields(params.instances)
  if params.instances[k] != null
};

// Gather ArgoCD instances
local argocd_configs = std.mapWithKey(function(k, v) std.get(v, 'config', {}), instances);

// Ensure there are no duplicate namespaces
local argocds = std.foldl(
  function(acc, k)
    local ns = namespacedName(k).namespace;
    if std.setMember(ns, acc.seen) then
      error "Component argocd doesn't support deploying multiple ArgoCD instances in a single namespace"
    else
      acc { seen+: [ ns ] },

  std.objectFields(instances),

  {
    seen: [],
    argocds: argocd_configs,
  }
).argocds;


// Gather AppProject instances
local projects = std.mapWithKey(function(k, v) std.get(v, 'projects', {}), instances);

// Flatten AppProjects, generating a namespaced name as the key
local appprojects = {
  [namespacedName(argocd).namespace + '/' + project]: projects[argocd][project]
  for argocd in std.objectFields(projects)
  for project in std.objectFields(projects[argocd])
  // remove nulled objects
  if projects[argocd][project] != null
};

{
  '00_argocds': com.generateResources(argocds, ArgoCD),
  '10_approjects': com.generateResources(appprojects, AppProject),
}
