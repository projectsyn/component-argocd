local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('argocd', params.namespace);

{
  'argocd': app,
}
