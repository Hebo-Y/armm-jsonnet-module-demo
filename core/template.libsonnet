function (params) 

assert std.isArray(params)|| std.isObject(params) : 'param should be an array or an object';

local resources = {
    resources:
        super.resources + 
        if std.isObject(params) then 
            if std.objectHas(params,'resources') then 
                params.resources
            else
                []
        else
            std.flattenArrays([params[i].resources for i in std.range(0,std.length(params)-1) if std.objectHas(params[i],'resources')]),
};

local getObjects(p,f) =
    if std.isObject(p) then 
        if std.objectHas(p,f) then 
            p[f]
        else
            {}
    else
        local l = std.filter(function(o) std.objectHas(o,f),p);
        std.foldr(function(a,b) a[f]+b,l,{});

local outputs = {
    outputs:
        super.outputs + getObjects(params,'outputs')
};

local parameters = {
    parameters:
        super.parameters +  getObjects(params,'parameters')
};

local variables = {
    variables:
        super.variables +  getObjects(params,'variables')
};

{
    '$schema': 'https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#',
    contentVersion: '0.0.0.1',
    parameters: {},
    variables:{},
    resources: [],
    outputs:{},  
}
+ resources
+ outputs
+ parameters
+ variables