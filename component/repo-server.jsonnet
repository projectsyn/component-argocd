local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;
local image = '%(registry)s/%(repository)s:%(tag)s' % params.images.argocd;
local common = import 'common.libsonnet';
local loadManifest = common.loadManifest;

local isOpenshift = std.startsWith(params.distribution, 'openshift');
local deployment = loadManifest('repo-server/argocd-repo-server-deployment.yaml');
local service = loadManifest('repo-server/argocd-repo-server-service.yaml');
local vault_agent_config = kube.ConfigMap('vault-agent-config') {
  data: {
    'vault-agent-config.json': std.manifestJson({
      exit_after_auth: false,
      auto_auth: {
        method: [
          {
            type: 'kubernetes',
            [if std.objectHas(inv.parameters.secret_management, 'vault_auth_mount_path') then 'mount_path']: inv.parameters.secret_management.vault_auth_mount_path,
            config: {
              role: inv.parameters.secret_management.vault_role,
              token_path: '/var/run/secrets/syn/token',
            },
          },
        ],
        sinks: [
          {
            sink: {
              type: 'file',
              config: {
                path: '/home/vault/.vault-token',
                mode: std.parseOctal('0644'),
              },
            },
          },
        ],
      },
    }),
  },
};
local objects = [
  vault_agent_config,
  deployment {
    spec+: {
      template+: {
        spec+: {
          assert std.length(super.initContainers) == 1 : 'expected one upstream initContainer',
          initContainers: [
            super.initContainers[0] {
              image: image,
              imagePullPolicy: 'IfNotPresent',
            },
            {
              name: 'install-kapitan',
              image: '%(registry)s/%(repository)s:%(tag)s' % params.images.kapitan,
              imagePullPolicy: 'Always',
              command: [
                'cp',
                '-v',
                '/usr/local/bin/kapitan',
                '/custom-tools/',
              ],
              volumeMounts: [ {
                name: 'kapitan-bin',
                mountPath: '/custom-tools',
              } ],
            },
          ],
          containers: [ deployment.spec.template.spec.containers[0] {
            image: image,
            imagePullPolicy: 'IfNotPresent',
            command: [
              'uid_entrypoint.sh',
              'argocd-repo-server',
              '--redis',
              'argocd-redis:6379',
              '--loglevel',
              common.evaluate_log_level('repo_server'),
              '--logformat',
              common.evaluate_log_format('repo_server'),
            ],
            env+: com.envList(com.proxyVars {
              HOME: '/home/argocd',
            }),
            [if params.resources.repo_server != null then 'resources']:
              std.prune(params.resources.repo_server),
            volumeMounts+: [ {
              name: 'kapitan-bin',
              mountPath: '/usr/local/bin/kapitan',
              subPath: 'kapitan',
            }, {
              name: 'vault-token',
              mountPath: '/home/argocd/',
            } ],
          }, kube.Container('vault-agent') {
            name: 'vault-agent',
            image: '%(registry)s/%(repository)s:%(tag)s' % params.images.vault_agent,
            args: [
              'agent',
              '-config',
              '/etc/vault/vault-agent-config.json',
            ],
            [if !isOpenshift then 'securityContext']: {
              runAsUser: 100,
            },
            env_: com.proxyVars {
              VAULT_ADDR: inv.parameters.secret_management.vault_addr,
              SKIP_SETCAP: 'true',
            },
            [if params.resources.repo_server_vault_agent != null then 'resources']:
              std.prune(params.resources.repo_server_vault_agent),
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
          } ],
          volumes+: [ {
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
          } ],
        },
      },
    },
  },
  service,
];

{
  ['%s' % [ std.asciiLower(obj.kind) ]]: obj {
    metadata+: {
      namespace: params.namespace,
    },
  }
  for obj in objects
}
