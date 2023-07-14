local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.argocd;

local evaluate_log_level = function(component)
  std.get(params.log_level, component, params.log_level.default);
local evaluate_log_format = function(component)
  std.get(params.log_format, component, params.log_format.default);

local render_image(imagename, include_tag=false) =
  local imagespec = params.images[imagename];
  local image =
    if std.objectHas(imagespec, 'image') then
      std.trace(
        'Field `image` for selecting the container image `%s` has been deprecated in favor of fields `registry` and `repository`, please update your config' % imagename,
        imagespec.image
      )
    else
      '%(registry)s/%(repository)s' % imagespec;
  if include_tag then
    '%(image)s:%(tag)s' % { image: image, tag: imagespec.tag }
  else
    image;


{
  render_image: render_image,
  evaluate_log_level: evaluate_log_level,
  evaluate_log_format: evaluate_log_format,
}
