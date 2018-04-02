local template=(import 'core/template.libsonnet');
local options= 
{
    options:: 
    {
        name: 'publicIpAddress',
        generateIds:false,
        generateReferences:false,
        idleTimeoutInMinutes:4,
    } 
};

local ip=(import 'resources/publicIpAddresses.libsonnet')(options);
local baseTemplate=(import 'core/template.libsonnet');

baseTemplate(ip)