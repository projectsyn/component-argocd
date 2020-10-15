# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed

- Open source component ([#1])
- Update Argo CD to v1.6.1
- Update Kapitan to v0.29.1 ([#3])
- Update Argo CD to v1.7.4 ([#5])
- Update deprecated parameters ([#8])

### Added

- Ignore CA bundles of webhooks ([#2])
- Syn label to alert rules ([#7])

### Fixed

- Remove empty `finalizers` field on root app ([#2])
- Kapitan container image digest ([#4])

[Unreleased]: https://github.com/projectsyn/component-argocd/compare/546caccdd6868a8085aaa29d9e7a159ea53ff0aa..HEAD

[#1]: https://github.com/projectsyn/component-argocd/pull/1
[#2]: https://github.com/projectsyn/component-argocd/pull/2
[#3]: https://github.com/projectsyn/component-argocd/pull/3
[#4]: https://github.com/projectsyn/component-argocd/pull/4
[#5]: https://github.com/projectsyn/component-argocd/pull/5
[#7]: https://github.com/projectsyn/component-argocd/pull/7
[#8]: https://github.com/projectsyn/component-argocd/pull/8
