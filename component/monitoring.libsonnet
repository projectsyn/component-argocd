local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prometheus = import 'lib/prometheus.libsonnet';
local syn_teams = import 'syn/syn-teams.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.argocd;

local serviceMonitor(objname, name) =
  kube._Object('monitoring.coreos.com/v1', 'ServiceMonitor', objname) {
    metadata: {
      name: objname,
      namespace: params.namespace,
      labels: {
        name: objname,
        'app.kubernetes.io/name': name,
        'app.kubernetes.io/part-of': 'argocd',
      },
    },
    spec: {
      endpoints: [ {
        port: 'metrics',
      } ],
      selector: {
        matchLabels: {
          'app.kubernetes.io/name': name,
          'app.kubernetes.io/part-of': 'argocd',
        },
      },
    },
  };

local alert_rules =
  local team_label =
    if syn_teams.owner != null then
      '{{if eq $labels.project "syn"}}{{ "%s" }}{{else}}{{ $labels.project }}{{end}}' % syn_teams.owner
    else
      null;

  kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'argocd') {
    metadata: {
      name: 'argocd',
      namespace: params.namespace,
      labels: {
        name: 'argocd',
        role: 'alert-rules',
      } + params.monitoring.prometheus_rule_labels,
    },
    spec: {
      groups: [
        {
          name: 'argocd.rules',
          rules: [
            {
              alert: 'ArgoCDAppUnsynced',
              expr: 'argocd_app_info{exported_namespace="' + params.namespace + '", sync_status!="Synced"} > 0',
              'for': '10m',
              labels: std.prune({
                severity: 'warning',
                syn: 'true',
                syn_team: team_label,
              }),
              annotations: {
                message: 'Argo CD app {{ $labels.name }} is not synced',
                description: 'kubectl -n ' + params.namespace + ' describe app {{ $labels.name }}',
                dashboard: 'argocd',
              },
            },
            {
              alert: 'ArgoCDAppUnhealthy',
              expr: 'argocd_app_info{exported_namespace="' + params.namespace + '", health_status!="Healthy"} > 0',
              'for': '10m',
              labels: std.prune({
                severity: 'critical',
                syn: 'true',
                syn_team: team_label,
              }),
              annotations: {
                message: 'Argo CD app {{ $labels.name }} is not healthy',
                description: 'kubectl -n ' + params.namespace + ' describe app {{ $labels.name }}',
                dashboard: 'argocd',
              },
            },
            {
              alert: 'ArgoCDDown',
              expr: 'up{namespace="' + params.namespace + '", job=~"^syn-argocd-.+$"} != 1',
              'for': '5m',
              labels: std.prune({
                severity: 'critical',
                syn: 'true',
                syn_team: team_label,
              }),
              annotations: {
                message: 'Argo CD job {{ $labels.job }} is down',
                dashboard: 'argocd',
              },
            },
          ],
        },
      ],
    },
  };

local grafana_dashboard =
  kube._Object('integreatly.org/v1alpha1', 'GrafanaDashboard', 'argocd') {
    metadata: {
      name: 'argocd',
      namespace: params.namespace,
      labels: {
        name: 'argocd',
      },
    },
    spec: {
      name: 'argocd',
      url: 'https://raw.githubusercontent.com/argoproj/argo-cd/' + params.images.argocd.tag + '/examples/dashboard.json',
    },
  };

local promEnable = function(obj)
  if std.member(inv.applications, 'prometheus') then
    prometheus.Enable(obj)
  else obj
;

[
  // We explicitly select names for the service monitors which don't match the
  // operator-generated names for instance syn-argocd
  promEnable(serviceMonitor('syn-component-argocd-metrics', 'syn-argocd-metrics')),
  promEnable(serviceMonitor('syn-component-argocd-server-metrics', 'syn-argocd-server-metrics')),
  promEnable(serviceMonitor('syn-component-argocd-repo-server', 'syn-argocd-repo-server')),
  promEnable(alert_rules),
] + if params.monitoring.dashboards then [ grafana_dashboard ] else []
