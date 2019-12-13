local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local argocd = import 'lib/argocd.libjsonnet';

local project = argocd.Project('syn');
local root_app = argocd.App('root', params.namespace) {
  spec+: {
    source+: {
      path: 'manifests/apps/',
    },
  },
};

local app = argocd.App('argocd', params.namespace);

{
  '00_syn-project': project,
  '01_rootapp': root_app,
  'argocd': app,
}
