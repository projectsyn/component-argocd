local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

// create aggregated clusterrole for access to ArgoCD custom resources.

local custom_resources = {
  apiGroups: [ 'argoproj.io' ],
  resources: [ 'applications', 'appprojects' ],
};

local aggregated_rbac = [
  kube.ClusterRole('syn-argocd-view') {
    metadata: {
      name: 'syn-argocd-view',
      labels: {
        name: 'syn-argocd-view',
        'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
        'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
        'rbac.authorization.k8s.io/aggregate-to-view': 'true',
      },
    },
    rules: [
      custom_resources {
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
    ],
  },
  kube.ClusterRole('syn-argocd-edit') {
    metadata: {
      name: 'syn-argocd-edit',
      labels: {
        name: 'syn-argocd-edit',
        'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
        'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
      },
    },
    rules: [
      custom_resources {
        verbs: [
          'create',
          'delete',
          'deletecollection',
          'patch',
          'update',
        ],
      },
    ],
  },
];

// Create custom cluster roles that are suitable to be used for
// argocd-operator's `CONTROLLER_CLUSTER_ROLE` and `SERVER_CLUSTER_ROLE`, cf.
// https://argocd-operator.readthedocs.io/en/latest/usage/custom_roles/
// NOTE(sg): we only deploy these cluster roles if the respective
// `cluster_role_match_labels` parameter in `operator` isn't empty.
local internalControllerAggregationLabel = {
  'rbac.argocd.syn.tools/aggregate-to-controller': 'true',
};

local custom_controller_cr =
  kube.ClusterRole(common.custom_cluster_role_name('application-controller')) {
    metadata+: {
      annotations+: {
        'syn.tools/description': |||
          Custom ClusterRole which is used to give the ArgoCD application
          controller access to managed namespaces. Intended to be configured
          as `CONTROLLER_CLUSTER_ROLE` on the operator.

          This ClusterRole aggregates the rules of all clusterroles which
          match one of the selectors in `aggregationRule.clusterRoleSelectors`.
        |||,
      },
    },
    rules:: [],
    aggregationRule: {
      clusterRoleSelectors: [
        { matchLabels: internalControllerAggregationLabel },
      ] + [
        sel
        for sel in
          std.objectValues(params.operator.controller_cluster_role_selectors)
        if sel != null
      ],
    },
  };

local controller_required_cr =
  kube.ClusterRole('syn:argocd-application-controller:required') {
    metadata+: {
      labels+: internalControllerAggregationLabel,
      annotations+: {
        'syn.tools/description': |||
          Custom ClusterRole which is used to aggregate a basic set of
          permissions to the custom ArgoCD application controller clusterrole
          `%s`.

          This rule is required to allow the application controller to run
          normally (emitting events, updating application status, etc)
        ||| % common.custom_cluster_role_name('application-controller'),
      },
    },
    rules: [
      // NOTE(sg): I wasn't able to fully determine why this is required, but
      // the application controller logs errors when it doesn't have
      // permissions to read secrets in target namespaces.
      {
        apiGroups: [ '' ],
        resources: [ 'secrets' ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
      // Required to access and update argocd apps which the controller is
      // managing.
      {
        apiGroups: [ 'argoproj.io' ],
        resources: [
          'applications',
          'applicationsets',
          'appprojects',
        ],
        verbs: [
          'create',
          'get',
          'list',
          'watch',
          'update',
          'delete',
          'patch',
        ],
      },
      // Required to emit events for app state changes and similar
      {
        apiGroups: [ '' ],
        resources: [ 'events' ],
        verbs: [ 'create', 'list', 'patch' ],
      },
      // Required for running hook jobs
      {
        apiGroups: [ 'batch' ],
        resources: [
          'jobs',
        ],
        verbs: [
          'create',
          'get',
          'list',
          'watch',
          'update',
          'delete',
          'patch',
        ],
      },
    ],
  };

local internalServerAggregationLabel = {
  'rbac.argocd.syn.tools/aggregate-to-server': 'true',
};

local custom_server_cr =
  kube.ClusterRole(common.custom_cluster_role_name('server')) {
    metadata+: {
      annotations+: {
        'syn.tools/description': |||
          Custom ClusterRole which is used to give the ArgoCD server access to
          managed namespaces. Intended to be configured as
          `SERVER_CLUSTER_ROLE` on the operator.

          This ClusterRole aggregates the rules of all clusterroles which
          match one of the selectors in `aggregationRule.clusterRoleSelectors`.
        |||,
      },
    },
    rules:: [],
    aggregationRule: {
      clusterRoleSelectors: [
        { matchLabels: internalServerAggregationLabel },
      ] + [
        sel
        for sel in
          std.objectValues(params.operator.server_cluster_role_selectors)
        if sel != null
      ],
    },
  };

local server_required_cr =
  kube.ClusterRole('syn:argocd-server:required') {
    metadata+: {
      labels+: internalServerAggregationLabel,
      annotations+: {
        'syn.tools/description': |||
          Custom ClusterRole which is used to aggregate some required rules to
          the ArgoCD server custom clusterrole `%s`.

          The rules in this role are necessary to allow the ArgoCD server to
          fetch the information it needs to display its web interface and to
          perform operations on its managed ArgoCD apps.
        ||| % common.custom_cluster_role_name('server'),
      },
    },
    rules: [
      // required to determine status of resources to display in the web
      // interface. In theory, this could be restricted, but the main really
      // critical namespaced resource is `secrets` which we need to give full
      // permissions on anyway.
      {
        apiGroups: [ '*' ],
        resources: [ '*' ],
        verbs: [ 'get' ],
      },
      // required so users can configure ArgoCD from the server web interface.
      // The server doesn't work correctly without this even if no
      // configuration via web interface is required.
      {
        apiGroups: [ '' ],
        resources: [ 'secrets', 'configmaps' ],
        verbs: [
          'create',
          'get',
          'list',
          'watch',
          'update',
          'patch',
          'delete',
        ],
      },
      // required so users can create and modify argocd apps and projects from
      // the web interface.
      {
        apiGroups: [ 'argoproj.io' ],
        resources: [
          'applications',
          'applicationsets',
          'appprojects',
        ],
        verbs: [
          'create',
          'get',
          'list',
          'watch',
          'update',
          'delete',
          'patch',
        ],
      },
      // required so the server can emit events
      {
        apiGroups: [ '' ],
        resources: [ 'events' ],
        verbs: [ 'create', 'list', 'patch' ],
      },
      // NOTE(sg): I assume this is also required for hook jobs, but haven't
      // found solid evidence for or against that assumption.
      {
        apiGroups: [ 'batch' ],
        resources: [
          'jobs',
          'cronjobs',
          'cronjobs/finalizers',
        ],
        verbs: [ 'create', 'update' ],
      },
    ],
  };

{
  ['%s-%s' % [ obj.metadata.name, std.asciiLower(obj.kind) ]]: obj
  for obj in aggregated_rbac
} + {
  [if std.length(custom_controller_cr.aggregationRule.clusterRoleSelectors) > 1
  then 'custom_controller_clusterrole']: [ custom_controller_cr, controller_required_cr ],
  [if std.length(custom_server_cr.aggregationRule.clusterRoleSelectors) > 1
  then 'custom_server_clusterroles']: [ custom_server_cr, server_required_cr ],
}
