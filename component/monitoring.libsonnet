local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prometheus = import 'lib/prometheus.libsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

local serviceMonitor(name) =
  kube._Object('monitoring.coreos.com/v1', 'ServiceMonitor', name) {
    metadata+: {
      namespace: params.namespace,
      labels+: {
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
  kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'argocd') {
    metadata+: {
      namespace: params.namespace,
      labels+: {
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
              labels: {
                severity: 'warning',
                syn: 'true',
              },
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
              labels: {
                severity: 'critical',
                syn: 'true',
              },
              annotations: {
                message: 'Argo CD app {{ $labels.name }} is not healthy',
                description: 'kubectl -n ' + params.namespace + ' describe app {{ $labels.name }}',
                dashboard: 'argocd',
              },
            },
            {
              alert: 'ArgoCDDown',
              expr: 'up{namespace="' + params.namespace + '", job=~"^argocd-.+$"} != 1',
              'for': '5m',
              labels: {
                severity: 'critical',
                syn: 'true',
              },
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
    metadata+: {
      namespace: params.namespace,
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
  promEnable(serviceMonitor('argocd-metrics')),
  promEnable(serviceMonitor('argocd-server-metrics')),
  promEnable(serviceMonitor('argocd-repo-server')),
  promEnable(alert_rules),
] + if params.monitoring.dashboards then [ grafana_dashboard ] else []
