{
    getOptions(p)::

        if std.isObject(p) && std.objectHas(p,'parameters') && std.length(p.parameters) > 0 then 
            {
            options:: {[n] :p.parameters[n].value, for n in std.objectFields(p.parameters)}
            }
        else
            {
            options::{}
            },
    getResults(resource):: {
        resources+: [ 
            resource.getGeneratedResource(r) 
            + resource.getSku(resource.resourceParameters) 
            + resource.getProperties(resource.resourceParameters,r,std.length(resource.generatedResources)) 
            + resource.getZones(resource.resourceParameters,r,std.length($.resource.generatedResources))
            for  r in std.range(0,std.length(resource.generatedResources)-1)
        ],   
        outputs+: resource.outputs,
    },
}