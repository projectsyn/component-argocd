local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

local evaluate_log_level = function(component)
  std.get(params.log_level, component, params.log_level.default);
local evaluate_log_format = function(component)
  std.get(params.log_format, component, params.log_format.default);

local render_image(imagename, include_tag=false) =
  local imagespec = params.images[imagename];
  local img = '%(registry)s/%(repository)s' % imagespec;
  local image =
    if std.objectHas(imagespec, 'image') && imagespec.image != null then
      std.trace(
        'Field `image` for selecting the container image `%s` has been removed. Please use fields `registry` and `repository` instead' % imagename,
        img
      )
    else
      img;
  if include_tag then
    '%(image)s:%(tag)s' % { image: image, tag: imagespec.tag }
  else
    image;

local custom_cr_name(component) =
  assert
    std.member([ 'server', 'application-controller' ], component) :
    'Custom clusterrole only supported for server and application-controller';
  'syn:argocd-%s:custom' % component;

{
  render_image: render_image,
  evaluate_log_level: evaluate_log_level,
  evaluate_log_format: evaluate_log_format,
  custom_cluster_role_name: custom_cr_name,
}
