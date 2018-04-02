function(obj)

local core = import 'core/module.libsonnet';

// makes sure that domain name segments are valid

local checkdomainNamePart(s) =
        assert std.isString(s) : 'domainNamePart must be a string got -' + s;
        local l=std.length(s);
        assert l >2 && l< 63: 'domainNamePart must be between 3 and 63 charcters long got -' + s + ' ' + l;
        assert std.setMember(std.substr(s, 0, 1),'abcdefghijklmnopqrstuvwxyz'): 'domainNamePart should start with a-z got -' + s;
        assert std.setMember(std.substr(s, l-1, 1),'0123456789abcdefghijklmnopqrstuvwxyz-'): 'domainNamePart should end with a-z or 0-9 got -' + s;
        assert !(std.length(std.filter(function (c) (!std.setMember(c,'0123456789abcdefghijklmnopqrstuvwxyz-')),std.stringChars(s))) > 0): 'domainNamePart should only contain 0-9, a-z or - got -' + s;
        true;

// Get the SkuName if present

local skuName(p)=
    if std.objectHasAll(p,'skuName') then
        assert std.isString(p.skuName) : 'skuName should be a string - got - ' + std.type(p.skuName);
        assert std.asciiLower(p.skuName) =='standard' ||  std.asciiLower(p.skuName) =='basic' :'skuName should be standard or basic - got - ' + p.skuName;
        std.asciiLower(p.skuName)
    else
        null;

// Validate that publicIPAddressVersion is an allowed value

local getPublicIPAddressVersion(p)=
    if std.objectHasAll(p,'publicIPAddressVersion') then
        assert std.isString(p.publicIPAddressVersion) : 'publicIPAddressVersion should a string';
        local publicIPAddressVersion=std.asciiLower(p.publicIPAddressVersion);
        assert publicIPAddressVersion =='ipv4'|| publicIPAddressVersion =='ipv6' : 'publicIPAddressVersion should be IPv4 or IPv6 - got ' + p.publicIPAddressVersion;
        assert  (skuName(p) == null || skuName(p) == 'basic') || (publicIPAddressVersion =='ipv4' && skuName(p) == 'standard' ) : 'publicIPAddressVersion must be ipv4 when sku is standard- got ' + p.publicIPAllocationMethod;
        {publicIPAddressVersion: p.publicIPAddressVersion}
    else
        {};

local isIPv4(p)=
     local publicIPAddressVersion=if std.objectHas(getPublicIPAddressVersion(p),'publicIPAddressVersion') then std.asciiLower(getPublicIPAddressVersion(p).publicIPAddressVersion) else 'ipv4';
     publicIPAddressVersion=='ipv4';

// validate that idle timeout is betwen 4 and 30 minutes

local getIdleTimeoutInMinutes(p)= 
    if std.objectHasAll(p,'idleTimeoutInMinutes') then
        assert std.isNumber(p.idleTimeoutInMinutes): 'idleTimeoutInMinutes should be a number - got - ' + std.type(p.idleTimeoutInMinutes);
        assert isIPv4(p): 'idleTimeoutinMinutes should not be set when address type is not ipv4';
        assert p.idleTimeoutInMinutes > 3 && p.idleTimeoutInMinutes < 31: 'idleTimeoutInMinutes should be between 4 and 30 - got - ' + p.idleTimeoutInMinutes;
        {idleTimeoutInMinutes : p.idleTimeoutInMinutes}
    else 
        {};

// domainNameLabel and reversfqdn can be either strings or arrays if an array there must be an equal number of elelemtns and instances

local dnsSettings(p,r,n)=
    if  std.objectHasAll(p,'domainNameLabel') || std.objectHasAll(p,'reverseFqdn') then

        local domainNameLabel=
             if  std.objectHasAll(p,'domainNameLabel') then 
                assert std.isString(p.domainNameLabel) || std.isArray(p.domainNameLabel): 'domainNameLabel should be a string or an array';
                local label = 
                    if (std.isString(p.domainNameLabel)) then
                        if n == 1 then p.domainNameLabel else p.domainNameLabel+(r+1)
                    else
                        assert std.length(p.domainNameLabel) == n: 'Number of domainName Labels must equal number of instances';
                        assert std.length(std.uniq(p.domainNameLabel)) == n: 'domainNameLabels must be unique';
                        p.domainNameLabel[r];

                if checkdomainNamePart(label) then
                    { 
                        dnsSettings +: {
                            domainNameLabel: label,
                        }
                    }
                else
                    {}
            else
                {};

        local reverseFqdn=
            if std.objectHasAll(p,'reverseFqdn') then
                assert std.isString(p.reverseFqdn) || std.isArray(p.reverseFqdn): 'reverseFqdn should be a string or an array';
                 local fqdn = 
                    if (std.isString(p.reverseFqdn)) then
                        p.reverseFqdn
                    else
                        assert std.length(p.reverseFqdn) == n: 'Number of reverseFqdns must equal number of instances';
                        p.reverseFqdn[r];
                local parts=std.split(fqdn,'.');
                local noOfParts=std.length(parts);
                assert noOfParts > 1: 'reverseFqdn must have at least 2 parts got - '+ fqdn;
                local leftParts=std.makeArray(noOfParts-1,function(i) parts[i]);
                assert std.length(std.filter(function(s) checkdomainNamePart(s),leftParts)) == noOfParts-1: 'reverseFQDN  invalid';
                { 
                    dnsSettings +: {
                        reverseFqdn:fqdn,
                    }
                }
            else
                {};
        domainNameLabel+reverseFqdn
    else
        {};

// Validate that publicIPAllocationMethod is an allowed value

local publicIPAllocationMethod(p,s)=
    if std.objectHasAll(p,'publicIPAllocationMethod') then
        assert std.isString(p.publicIPAllocationMethod) : 'publicIPAllocationMethod should a string';
        local publicIPAllocationMethod=std.asciiLower(p.publicIPAllocationMethod);
        assert publicIPAllocationMethod =='dynamic'|| publicIPAllocationMethod =='static' : 'publicIPAllocationMethod should be static or dynamic - got ' + p.publicIPAllocationMethod;
        assert  (skuName(p) == null || skuName(p) == 'basic') || (publicIPAllocationMethod =='static' && skuName(p) == 'standard' ) : 'publicIPAllocationMethod must be static when sku is standard- got ' + p.publicIPAllocationMethod;
        local ipv4=isIPv4(p);
        assert ipv4  || !ipv4 && publicIPAllocationMethod =='dynamic': 'IPv6 addresses cannot be static';
        {publicIPAllocationMethod: publicIPAllocationMethod}
    else 
        {};

// Get ipTags

local ipTags(p)=
    if std.objectHasAll(p,'ipTags') then
        assert std.isString(p.ipTags) || std.isArray(p.ipTags) : 'ipTags should be Array or String';
        {ipTags: if std.isString(p.ipTags) then [p.ipTags] else p.ipTags}
    else
        {};

local zones(p,r,c)=
    if std.objectHasAll(p,'zones') then 
        assert skuName(p)=='standard':'skuName must be standard for zones support';
        assert std.isArray(p.zones) || std.isString(p.zones) || std.isNumber(p.zones): 'zones must be an array string or number';
        local zone=
            if std.isArray(p.zones) then
                local noOfZones=std.length(p.zones);
                local zoneNumber=std.mod(r+noOfZones,noOfZones);
                assert std.isString(p.zones[zoneNumber]) || std.isNumber(p.zones[zoneNumber]): 'zones array elements must be string or number';
                [std.toString(p.zones[zoneNumber])]
            else
                [std.toString(p.zones)];
        {
            zones:zone
        }
    else
        {};



local resource= core.Resource {
        resourceParameters :: {
            type: 'Microsoft.Network/publicIpAddresses',
            apiVersion: '2018-01-01',
            supportsZones:true,
        } 
        + obj.options,
        getProperties(p,r,c) :: {
            properties: {        
            } 
            + getIdleTimeoutInMinutes(p) 
            + getPublicIPAddressVersion(p)
            + publicIPAllocationMethod(p,$)
            + ipTags(p)
            + dnsSettings(p,r,c),
        },
        getSku(p)::
            local name= skuName(p);
            if name != null then
                {
                    sku:{ 
                        name: name
                    }
                }
            else
                {},
        getZones(p,r,c) :: zones(p,r,c)
          
};

assert !(resource.isMSISupported(resource.resourceParameters)) : 'publicIpAddresses does not support MSI';
assert resource.isTracked(resource.resourceParameters) : 'publicIpAddresses should be tracked';
core.Module.getResults(resource)