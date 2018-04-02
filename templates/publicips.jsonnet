function ()

local ip=(import 'resources/publicIpAddresses.libsonnet');
local tags ={"tag1":"value1","tag2":"value2",};
local baseOptions=
{ 
    options:: {
            name: 'basePip',
            tags:tags
    } 
};
local basePip=ip(baseOptions);
local pip1Options=baseOptions 
+
{
    options+::
    { 
        name: 'pip1',
        instanceCount:15,
        generateIds:true,
        generateReferences:true,
    },
};
local pip1=ip(pip1Options);
local pip2Options=baseOptions 
+
{
    options+:: {
        name: 'pip2',
        skuName: 'standard',
        publicIPAllocationMethod: 'static',
        idleTimeoutInMinutes:4,
        
    }
};
local pip2=ip(pip2Options);
local additionalTags= {"tag3":"value3","tag4":"value4",};
local pip3Options=baseOptions 
+
{
    options+:: {
        name: 'pip3',
        location: "northeurope",
        instanceCount:5,
        dependsOnAcrossResources: [pip2.resources[i].name for i in std.range(0,std.length(pip2.resources)-1)],
        serial:'True',
        tags+:additionalTags,
        batchSize:2,
    } +
    {
        dependsOnPerResource:['explicitdependency'],
    },
};
local pip3=ip(pip3Options);
local baseTemplate=(import 'core/template.libsonnet');
baseTemplate(basePip+pip1+pip2+pip3)