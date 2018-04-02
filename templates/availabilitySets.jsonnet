function (params) 

// Create a parameter for generated the availability set template

local templateParameters={
    parameters: {
        location: {
            defaultValue: "[resourceGroup().location]",
            type: "string"
        }
    },
};

// Create an availability set resource with parameters passed to jsonnet and add the parameter definition above
// Overwrite the location provided in the params argument if there is one

local availabilitySets=(import 'resources/availabilitySets.libsonnet')
( 
+ (import 'core/module.libsonnet').Module.getOptions(params)
+ {properties+::{location:"[parameters('location')]"}}
+ templateParameters);

// Output the template with the created resource(s)

local template=(import 'core/template.libsonnet');
template(availabilitySets)
