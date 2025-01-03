local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local argocd = import 'lib/argocd.libjsonnet';

local syn_project = argocd.Project('syn');
local default_project = argocd.Project('default') {
  spec: {
    destinations: [ {
      namespace: '*',
      server: '*',
    } ],
    clusterResourceWhitelist: [ {
      group: '*',
      kind: '*',
    } ],
    sourceRepos: [ '*' ],
  },
};
local root_app = argocd.App('root', params.namespace, secrets=false) {
  metadata: {
    name: 'root',
    namespace: params.namespace,
  },
  spec+: {
    source+: {
      path: 'manifests/apps/',
    },
    syncPolicy+: {
      automated+: {
        prune: false,
      },
    },
  },
};

local app = argocd.App('argocd', params.namespace, secrets=false) {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/compare-options': 'ServerSideDiff=true',
    },
  },
  spec+: {
    syncPolicy+: {
      syncOptions+: [
        'ServerSideApply=true',
      ],
      automated+: {
        [if params.operator.migrate then 'prune' else null]: false,
      },
    },
  },
};

{
  '00_syn-project': syn_project,
  '00_default-project': default_project,
  '01_rootapp': root_app,
  '10_argocd': app,
}
