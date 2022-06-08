local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

local loadManifest = function(path)
  std.parseJson(kap.yaml_load('argocd/manifests/' + params.images.argocd.tag + '/' + path));

{
  loadManifest: loadManifest,
}
