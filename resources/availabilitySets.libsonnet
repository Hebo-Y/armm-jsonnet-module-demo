function(obj)

local core = import 'core/module.libsonnet';  
local resource=core.Resource {
    resourceParameters :: {
        type: 'Microsoft.Compute/availabilitySets',
        apiVersion: '2017-12-01'
    } 
    + obj.options,
};

assert !(std.objectHasAll(resource.resourceParameters,'supportsMSI')) : 'availabilitySets does not support MSI';
assert resource.isTracked(resource.resourceParameters) : 'availabilitySets should be tracked';
core.Module.getResults(resource)