local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

local evaluate_log_level = function(component)
  std.get(params.log_level, component, params.log_level.default);
local evaluate_log_format = function(component)
  std.get(params.log_format, component, params.log_format.default);

local loadManifest = function(path)
  std.parseJson(kap.yaml_load('argocd/manifests/' + params.images.argocd.tag + '/' + path));

{
  loadManifest: loadManifest,
  evaluate_log_level: evaluate_log_level,
  evaluate_log_format: evaluate_log_format,
}
