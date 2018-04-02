function (args) 

local publicIPAddress=(import 'resources/publicIpAddresses.libsonnet');

local getResources()=

    // Check to see if publicIPAdressVersion is both if so generate two IP addresses one IPV4 and one IPV6

    if std.objectHasAll(args.options,'publicIPAddressVersion') && std.isString(args.options.publicIPAddressVersion) && std.asciiLower(args.options.publicIPAddressVersion) == 'both' then

        assert !(std.objectHasAll(args.options,'skuName')) || (std.objectHasAll(args.options,'skuName') && std.asciiLower(args.options.skuName)=='basic'):'cannot have standard SkuName when publicIPAdressVersion is both';
        assert !(std.objectHasAll(args.options,'zones')) :'cannot have zones when publicIPAdressVersion is both';
        local ipv4args=args+{options+::{publicIPAddressVersion:'ipv4'}};
        local ipv4=publicIPAddress(ipv4args);
        local name='ipv6-'+args.options.name;
        local ipv6args=args+{options+::std.prune({

                name:name,
                publicIPAddressVersion:'ipv6',
                publicIPAllocationMethod:'dynamic',
                idleTimeoutInMinutes:null,
            })
        };
        local ipv6=publicIPAddress(ipv6args);    
        [ipv4,ipv6]
    else
      publicIPAddress(args);

// Output the template with the created resource(s)

local template=(import 'core/template.libsonnet');


template(getResources())
