function (params) 

// Create publicip.jsonnet Resource(s) using options passed in

local args=(import 'core/module.libsonnet').Module.getOptions(params);
local ip=import 'resources/publicip.libsonnet';

// Output the template with the created resource(s)

local template=(import 'core/template.libsonnet');
template(ip(args))
