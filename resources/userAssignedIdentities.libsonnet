function(obj)

local core = import 'core/module.libsonnet';  
local resource=core.Resource {
    resourceParameters :: {
        type: 'Microsoft.ManagedIdentity/userAssignedIdentities',
        apiVersion: '2015-08-31-PREVIEW'
    } 
    + obj.options,
};

assert !(std.objectHasAll(resource.resourceParameters,'supportsMSI')) : 'userAssignedIdentities does not support MSI';
assert resource.isTracked(resource.resourceParameters) : 'userAssignedIdentities should be tracked';

core.Module.getResults(resource)