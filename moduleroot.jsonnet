function (params) 

// Create userAssignedIdentities.jsonnet Resource(s) using options passed in

local ids=(import 'resources/userAssignedIdentities.libsonnet')  ((import 'core/module.libsonnet').Module.getOptions(params));

// Output the template with the created resource(s)

local template=(import 'core/template.libsonnet');
template(ids)
