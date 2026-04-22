local esp = import 'lib/espejote.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();

local params = inv.parameters.argocd;

// Check if espejote is installed and resources are configured
local hasEspejote = std.member(inv.applications, 'espejote');

if hasEspejote then
  {
    '10_argocd_priority_class': esp.admission('argocd-set-priority-class', params.namespace) {
      spec: {
        mutating: true,
        template: importstr 'espejote-templates/argocd-priority-class.jsonnet',
        webhookConfiguration: {
          rules: [
            {
              apiGroups: [ '' ],
              apiVersions: [ '*' ],
              operations: [ 'CREATE' ],
              resources: [ 'pods' ],
            },
          ],
          objectSelector: {
            matchExpressions: [ {
              key: 'app.kubernetes.io/name',
              operator: 'In',
              values: [
                'syn-argocd-server',
                'syn-argocd-repo-server',
                'syn-argocd-application-controller',
                'syn-argocd-redis',
              ],
            } ],
          },
        },
      },
    },
  }
else {}
