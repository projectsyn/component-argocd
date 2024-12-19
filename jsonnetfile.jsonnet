{
  version: 1,
  dependencies: [
    {
      source: {
        git: {
          remote: 'https://github.com/projectsyn/jsonnet-libs',
          subdir: '',
        },
      },
      version: 'main',
      name: 'syn',
    },
  ],
  legacyImports: true,
}
