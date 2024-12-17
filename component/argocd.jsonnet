local cm = import 'lib/cert-manager.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.argocd;
local common = import 'common.libsonnet';
local isOpenshift = std.member([ 'openshift4', 'oke' ], params.distribution);

local resync_string =
  if std.get(params, 'resync_seconds', 0) > 0 then
    std.trace(
      'Parameter `resync_seconds` is deprecated. Please update your config to use `resync_time`',
      std.format('%dm0s', std.mod(params.resync, 60)),
    )
  else
    params.resync_time;

local applicationController = {
  processors: {
    operation: 10,
    status: 20,
  },
  appSync: resync_string,
  logLevel: common.evaluate_log_level('application_controller'),
  logFormat: common.evaluate_log_format('application_controller'),
  [if params.resources.application_controller != null then 'resources']:
    std.prune(params.resources.application_controller),
};

local redis = {
  image: common.render_image('redis'),
  version: params.images.redis.tag,
  [if params.resources.redis != null then 'resources']:
    std.prune(params.resources.redis),
};

local server = {
  insecure: true,
  logLevel: common.evaluate_log_level('server'),
  logFormat: common.evaluate_log_format('server'),
  [if params.resources.server != null then 'resources']:
    std.prune(params.resources.server),
};

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

local kapitan_plugin_config = kube.ConfigMap('kapitan-plugin-config') {
  data: {
    'plugin.yaml': std.manifestYamlDoc(
      {
        apiVersion: 'argoproj.io/v1alpha1',
        kind: 'ConfigManagementPlugin',
        metadata: {
          name: 'kapitan',
        },
        spec: {
          generate: {
            command: [
              'kapitan',
              'refs',
              '--reveal',
              '--refs-path',
              '../../refs/',
              '--file',
              './',
            ],
          },
        },
      }
    ),
  },
};

local repoServer = {
  image: common.render_image('argocd'),
  version: params.images.argocd.tag,
  logLevel: common.evaluate_log_level('repo_server'),
  logFormat: common.evaluate_log_format('repo_server'),
  env: com.envList(com.proxyVars {
    HOME: '/home/argocd',
  }),
  [if params.resources.repo_server != null then 'resources']:
    std.prune(params.resources.repo_server),
  volumeMounts: [
    {
      name: 'vault-token',
      mountPath: '/home/argocd/',
    },
  ],
  volumes: [
    {
      name: 'vault-token',
      emptyDir: {
        medium: 'Memory',
      },
    },
    {
      name: 'vault-config',
      configMap: {
        name: vault_agent_config.metadata.name,
      },
    },
    {
      name: 'steward-token',
      secret: {
        secretName: 'steward',
      },
    },
    {
      name: 'kapitan-plugin-config',
      configMap: {
        name: kapitan_plugin_config.metadata.name,
      },
    },
  ],
  sidecarContainers: [
    kube.Container('kapitan') {
      command: [ '/var/run/argocd/argocd-cmp-server' ],
      args: [
        '--loglevel',
        $.logLevel,
        '--logformat',
        $.logFormat,
      ],
      env_: com.proxyVars {
        HOME: '/home/argocd',
      },
      image: common.render_image('kapitan', include_tag=true),
      securityContext: {
        runAsNonRoot: true,
        // On non-OpenShift we use user 999, since the main repo-server
        // container also uses user 999 and we need to make sure that the main
        // repo-server container has write permissions on the cmp-server
        // socket created by this container.
        [if !isOpenshift then 'runAsUser']: 999,
      },
      volumeMounts_: {
        'var-files': {
          mountPath: '/var/run/argocd',
        },
        plugins: {
          mountPath: '/home/argocd/cmp-server/plugins',
        },
        kapitan_plugin_config: {
          mountPath: '/home/argocd/cmp-server/config/plugin.yaml',
          subPath: 'plugin.yaml',
        },
        'vault-token': {
          mountPath: '/home/argocd/',
        },
      },
    },
    kube.Container('vault-agent') {
      name: 'vault-agent',
      image: common.render_image('vault_agent', include_tag=true),
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
    },
  ],
};

local argocdOverride = com.makeMergeable({ spec: params.override });

local useHttpsCatalog = std.startsWith(inv.parameters.cluster.catalog_url, 'https://');

local argocd(name) =
  kube._Object('argoproj.io/v1beta1', 'ArgoCD', name) {
    metadata+: {
      name: name,
      namespace: params.namespace,
      annotations+: {
        'argocd.argoproj.io/sync-wave': '10',
      },
    },
    spec: {
      image: common.render_image('argocd'),
      version: params.images.argocd.tag,
      applicationInstanceLabelKey: 'argocd.argoproj.io/instance',
      controller: applicationController,
      initialRepositories: '- url: ' + inv.parameters.cluster.catalog_url,
      repositoryCredentials: if useHttpsCatalog then
        |||
          - url: %(catalog_url)s
            usernameSecret:
              name: %(secret)s
              key: username
            passwordSecret:
              name: %(secret)s
              key: password
        ||| % {
          catalog_url: inv.parameters.cluster.catalog_url,
          secret: params.http_credentials_secret_name,
        }
      else
        |||
          - url: ssh://git@
            sshPrivateKeySecret:
              name: argo-ssh-key
              key: sshPrivateKey
        |||,
      initialSSHKnownHosts: {
        keys: |||
          bitbucket.org ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAubiN81eDcafrgMeLzaFPsw2kNvEcqTKl/VqLat/MaB33pZy0y3rJZtnqwR2qOOvbwKZYKiEO1O6VqNEBxKvJJelCq0dTXWT5pbO2gDXC6h6QDXCaHo6pOHGPUy+YBaGQRGuSusMEASYiWunYN0vCAI8QaXnWMXNMdFP3jHAJH0eDsoiGnLPBlBp4TNm6rYI74nMzgz3B9IikW4WVK+dc8KZJZWYjAuORU3jc1c/NPskD2ASinf8v3xnfXeukU0sJ5N6m5E8VLjObPEO+mN2t/FZTMZLiFqPWc/ALSqnMnnhwrNi2rbfg/rd/IpL8Le3pSBne8+seeFVBoGqzHM9yXw==
          github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
          gitlab.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY=
          gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
          gitlab.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsj2bNKTBSpIYDEGk9KxsGh3mySTRgMtXL583qmBpzeQ+jqCMRgBqB98u3z++J1sKlXHWfM9dyhSevkMwSbhoR8XIq/U0tCNyokEi/ueaBMCvbcTHhO7FcwzY92WK4Yt0aGROY5qX2UKSeOvuP4D6TPqKF1onrSzH9bx9XUf2lEdWT/ia1NEKjunUqu1xOB/StKDHMoX4/OKyIzuS0q/T1zOATthvasJFoPrAjkohTyaDUz2LN5JoH839hViyEG82yB+MjcFV5MU3N1l1QL3cVUCh93xSaua1N85qivl+siMkPGbO5xR/En4iEY6K2XPASUEMaieWVNTRCtJ4S8H+9
          ssh.dev.azure.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTWqNqOlzGJOfGJ4NakVyIzf1rXYd4d7wo6jBlkLvCA4odBlL0mDUyZ0/QUfTTqeu+tm22gOsv+VrVTMk6vwRU75gY/y9ut5Mb3bR5BV58dKXyq9A9UeB5Cakehn5Zgm6x1mKoVyf+FFn26iYqXJRgzIZZcZ5V6hrE0Qg39kZm4az48o0AUbf6Sp4SLdvnuMa2sVNwHBboS7EJkm57XQPVU3/QpyNLHbWDdzwtrlS+ez30S3AdYhLKEOxAG8weOnyrtLJAUen9mTkol8oII1edf7mWWbWVf0nBmly21+nZcmCTISQBtdcyPaEno7fFQMDD26/s0lfKob4Kw8H
          vs-ssh.visualstudio.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTWqNqOlzGJOfGJ4NakVyIzf1rXYd4d7wo6jBlkLvCA4odBlL0mDUyZ0/QUfTTqeu+tm22gOsv+VrVTMk6vwRU75gY/y9ut5Mb3bR5BV58dKXyq9A9UeB5Cakehn5Zgm6x1mKoVyf+FFn26iYqXJRgzIZZcZ5V6hrE0Qg39kZm4az48o0AUbf6Sp4SLdvnuMa2sVNwHBboS7EJkm57XQPVU3/QpyNLHbWDdzwtrlS+ez30S3AdYhLKEOxAG8weOnyrtLJAUen9mTkol8oII1edf7mWWbWVf0nBmly21+nZcmCTISQBtdcyPaEno7fFQMDD26/s0lfKob4Kw8H
        ||| + params.ssh_known_hosts,
      },
      redis: redis,
      resourceExclusions: std.manifestYamlDoc(
        std.foldl(
          function(acc, v) acc + std.flattenArrays([ v ]),
          std.filter(function(v) v != null, std.objectValues(params.resource_exclusions)),
          []
        )
      ),
      resourceIgnoreDifferences: {
        resourceIdentifiers: [
          {
            group: 'admissionregistration.k8s.io',
            kind: 'MutatingWebhookConfiguration',
            customization: {
              jsonPointers: [ '/webhooks/0/clientConfig/caBundle' ],
            },
          },
          {
            group: 'admissionregistration.k8s.io',
            kind: 'ValidatingWebhookConfiguration',
            customization: {
              jsonPointers: [ '/webhooks/0/clientConfig/caBundle' ],
            },
          },
          {
            group: 'apiextensions.k8s.io',
            kind: 'CustomResourceDefinition',
            customization: {
              jsonPointers: [ '/status', '/spec/scope' ],
            },
          },
        ],
      },
      extraConfig: {
        'resource.customizations': std.manifestYamlDoc({
          'operators.coreos.com/Subscription': {
            // Required to enable Lua string functions like `string.find`
            'health.lua.useOpenLibs': true,
          },
        }),
      },
      resourceHealthChecks: [
        {
          group: 'pkg.crossplane.io',
          kind: 'Provider',
          check: |||
            hs = {}
            if obj.status ~= nil then
              if obj.status.conditions ~= nil then
                installed = false
                healthy = false
                for i, condition in ipairs(obj.status.conditions) do
                  if condition.type == "Installed" then
                    installed = condition.status == "True"
                    installed_message = condition.reason
                  elseif condition.type == "Healthy" then
                    healthy = condition.status == "True"
                    healthy_message = condition.reason
                  end
                end
                if installed and healthy then
                  hs.status = "Healthy"
                else
                  hs.status = "Degraded"
                end
                hs.message = installed_message .. " " .. healthy_message
                return hs
              end
            end

            hs.status = "Progressing"
            hs.message = "Waiting for provider to be installed"
            return hs
          |||,
        },
        {
          group: 'operators.coreos.com',
          kind: 'Subscription',
          check: |||
            hs = {}
            if obj.status ~= nil then
              if obj.status.conditions ~= nil then
                numDegraded = 0
                numPending = 0
                msg = ""
                for i, condition in pairs(obj.status.conditions) do
                  msg = msg .. i .. ": " .. condition.type .. " | " .. condition.status .. "\n"
                  if condition.type == "InstallPlanPending" and condition.status == "True" then
                    numPending = numPending + 1
                  elseif (condition.type == "CatalogSourcesUnhealthy" or condition.type == "InstallPlanMissing" or condition.type == "InstallPlanFailed" or condition.type == "ResolutionFailed") and condition.status == "True" then
                    -- Custom check to ignore ConstraintsNotSatisfiable for
                    -- cilium-enterprise subscription.
                    if condition.type == "ResolutionFailed"  and condition.reason == "ConstraintsNotSatisfiable" and string.find(condition.message, "cilium%-enterprise") then
                      msg = msg .. "; Ignoring ConstraintsNotSatisfiable for cilium-enterprise subscription"
                    else
                      numDegraded = numDegraded + 1
                    end
                  end
                end
                if numDegraded == 0 and numPending == 0 then
                  hs.status = "Healthy"
                  hs.message = msg
                  return hs
                elseif numPending > 0 and numDegraded == 0 then
                  hs.status = "Progressing"
                  hs.message = "An install plan for a subscription is pending installation"
                  return hs
                else
                  hs.status = "Degraded"
                  hs.message = msg
                  return hs
                end
              end
            end
            hs.status = "Progressing"
            hs.message = "An install plan for a subscription is pending installation"
            return hs
          |||,
        },
      ],
      repo: repoServer,
      server: server,
    },
  } + if std.length(params.override) > 0 then argocdOverride else {};

local ssh_secret = kube._Object('v1', 'Secret', 'argo-ssh-key') {
  type: 'Opaque',
};


// Manually adding certificate for conversion webhook
// as the upstream kustomize is broken.
// 2023/02/19 sfe
local webhook_certs = [
  cm.issuer('selfsigned-issuer') {
    metadata+: {
      namespace: params.operator.namespace,
    },
    spec: {
      selfSigned: {},
    },
  },
  cm.cert('serving-cert') {
    metadata+: {
      namespace: params.operator.namespace,
    },
    spec: {
      dnsNames: [
        'syn-argocd-operator-webhook-service.%s.svc' % params.operator.namespace,
        'syn-argocd-operator-webhook-service.%s.svc.cluster.local' % params.operator.namespace,
      ],
      issuerRef: {
        kind: 'Issuer',
        name: 'selfsigned-issuer',
      },
      secretName: 'webhook-server-cert',
    },
  },
];

// Manually trigger refresh of ArgoCD TLS certificate. Currently the operator
// will not do anything if it sees that the secret `syn-argocd-tls` exists
// even if the certificate stored in the secret expired or is expiring soon.
local tls_sa = kube.ServiceAccount('syn-argocd-tls-refresher') {
  metadata+: {
    namespace: params.namespace,
  },
};
local tls_role = kube.Role('syn-argocd-tls-refresher') {
  metadata+: {
    namespace: params.namespace,
  },
  rules: [ {
    apiGroups: [ '' ],
    resources: [ 'secrets' ],
    verbs: [ 'delete' ],
    resourceNames: [
      'syn-argocd-tls',
      'syn-argocd-ca',
    ],
  } ],
};
local tls_rolebinding = kube.RoleBinding('syn-argocd-tls-refresher') {
  metadata+: {
    namespace: params.namespace,
  },
  subjects_: [ tls_sa ],
  roleRef_: tls_role,
};
local tls_cronjob =
  local homedir = '/home/refresh';
  kube.CronJob('syn-argocd-tls-refresher') {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      failedJobsHistoryLimit: 3,
      // At 09:00 on the first day of the month every 4th month.
      schedule: '0 9 1 */4 *',
      jobTemplate+: {
        spec+: {
          template+: {
            spec+: {
              containers_: {
                refresh: kube.Container('refresh') {
                  image: common.render_image('kubectl'),
                  command: [
                    'kubectl',
                    'delete',
                    'secret',
                    'syn-argocd-tls',
                    'syn-argocd-ca',
                  ],
                  env_: {
                    HOME: homedir,
                  },
                  volumeMounts_+: {
                    home: { mountPath: homedir },
                  },
                },
              },
              serviceAccountName: tls_sa.metadata.name,
              volumes_+: {
                home: { emptyDir: {} },
              },
            },
          },
        },
      },
    },
  };

local tls_refresh = [
  tls_sa,
  tls_role,
  tls_rolebinding,
  tls_cronjob,
];

{
  '00_vault_agent_config': vault_agent_config,
  '00_kapitan_plugin_config': kapitan_plugin_config,
  '00_ssh_secret': ssh_secret,
  '10_argocd': argocd('syn-argocd'),
  [if params.network_policies.enabled then '20_networkpolicy']: std.map(function(p) com.namespaced(params.namespace, p), import 'networkpolicy.libsonnet'),
  // Manually adding certificate for conversion webhook
  // as the upstream kustomize is broken.
  // 2023/02/19 sfe
  [if params.operator.conversion_webhook then '../10_operator_webhook_certs']: webhook_certs,
  '10_refresh_argocd_tls': tls_refresh,
}
