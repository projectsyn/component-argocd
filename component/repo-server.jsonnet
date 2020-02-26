local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = params.images.argocd.image + ':' + params.images.argocd.tag;

local deployment = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/repo-server/argocd-repo-server-deployment.yaml'));
local service = std.parseJson(kap.yaml_load('argocd/manifests/' + params.git_tag + '/repo-server/argocd-repo-server-service.yaml'));
local vault_agent_config = kube.ConfigMap('vault-agent-config') {
  data: {
    'vault-agent-config.hcl': |||
      # exit_after_auth = false
      # pid_file = "/home/vault/pidfile"

      auto_auth {
          method "kubernetes" {
              config = {
                  role = "%s"
                  token_path = "/var/run/secrets/syn/token"
              }
          }
          sink "file" {
              config = {
                  path = "/home/vault/.vault-token"
                  # Write by user read by others
                  mode = 00204
              }
          }
      }
    ||| % inv.parameters.secret_management.vault_role,
  },
};
local objects = [
  vault_agent_config,
  deployment {
    spec+: {
      template+: {
        spec+: {
          initContainers+: [{
            name: 'install-kapitan',
            image: params.images.kapitan.image + ':' + params.images.kapitan.tag,
            imagePullPolicy: 'Always',
            command: [
              'cp',
              '-v',
              '/usr/local/bin/kapitan',
              '/custom-tools/',
            ],
            volumeMounts: [{
              name: 'kapitan-bin',
              mountPath: '/custom-tools',
            }],
          }],
          containers: [deployment.spec.template.spec.containers[0] {
            image: image,
            imagePullPolicy: 'IfNotPresent',
            volumeMounts+: [{
              name: 'kapitan-bin',
              mountPath: '/usr/local/bin/kapitan',
              subPath: 'kapitan',
            }, {
              name: 'vault-token',
              mountPath: '/home/argocd/',
            }],
          }, kube.Container('vault-agent') {
            name: 'vault-agent',
            image: params.images.vault_agent.image + ':' + params.images.vault_agent.tag,
            args: [
              'agent',
              '-config',
              '/etc/vault/vault-agent-config.hcl',
            ],
            env_: {
              VAULT_ADDR: inv.parameters.secret_management.vault_addr,
              SKIP_SETCAP: 'true',
            },
            volumeMounts_: {
              'vault-token': {
                mountPath: '/home/vault/',
              },
              'vault-config': {
                mountPath: '/etc/vault/',
              },
              'steward-token': {
                mountPath: '/var/run/secrets/syn/',
              },
            },
          }],
          volumes+: [{
            name: 'kapitan-bin',
            emptyDir: {},
          }, {
            name: 'vault-token',
            emptyDir: {
              medium: 'Memory',
            },
          }, {
            name: 'vault-config',
            configMap: {
              name: vault_agent_config.metadata.name,
            },
          }, {
            name: 'steward-token',
            secret: {
              secretName: 'steward',
            },
          }],
        },
      },
    },
  },
  service,
];

{
  ['%s' % [std.asciiLower(obj.kind)]]: obj {
    metadata+: {
      namespace: params.namespace,
    },
  }
  for obj in objects
}
