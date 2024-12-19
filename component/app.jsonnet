local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local argocd = import 'lib/argocd.libjsonnet';
local syn_teams = import 'syn/syn-teams.libsonnet';

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

local root_app(team) =
  local project = if team == 'root' then
    'syn'
  else
    team;

  local name = if team == 'root' then
    'root'
  else
    'root-%s' % team;

  argocd.App(name, params.namespace, secrets=false) {
    metadata: {
      name: name,
      namespace: params.namespace,
    },
    spec+: {
      project: project,
      source+: {
        path: if team == 'root' then
          'manifests/apps/'
        else
          'manifests/apps-%s/' % team,
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
  'apps/00_syn-project': syn_project,
  'apps/00_default-project': default_project,
  'apps/01_rootapp': root_app('root'),
  'apps/10_argocd': app,
} + {
  ['apps-%s/01_rootapp' % team]: root_app(team)
  for team in syn_teams.teams()
} + {
  ['apps-%s/00_project' % team]: argocd.Project(team)
  for team in syn_teams.teams()
}
