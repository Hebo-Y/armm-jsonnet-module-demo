{

    // This library implments common functionaility to validate and generate resources and outputs to be used in ARM Template    
    
    // The Maximum number of tags allowed on a resource
    local maxTags=15,
    // The Maximum length of a tag name
    local maxTagNameLength=512,
    // The Maximum length of a tag value
    local maxTagValueLength=256,
    // The maxium length of a Resource Name
    local maxResourceNameLength=260,
    // What is the maximum number of dependencies?
    local maxDependsOn=15,
    // The maximum number of instances of a resource that can be generated
    local maxInstances=100,
    // The maximum number of batches of resources that can be created
    local maxBatchSize=10,
    // The maximum number of explicit MSI references
    local maxMSIInstances=32,
    local msiRPAPIVersion='2015-08-31-PREVIEW',

    // Gets the maximum length of a field name in an object

    getMaxFieldNameLength(obj)::

        local fieldNameLengths=[std.length(l) for l in std.objectFields(obj)];
        self.getMaxValue(fieldNameLengths),

    // Gets the maximum length of a value in an object

    getMaxFieldValueLength(obj)::

        local fieldValues=[obj[n] for n in std.objectFields(obj)];
        local fieldValueLengths=[std.length(l) for l in fieldValues];
        self.getMaxValue(fieldValueLengths),

    // Gets the maximum value of an item in an array

    getMaxValue(arr)::

        local sortedValues=std.sort(arr);
        local index=std.length(sortedValues)-1;
        sortedValues[index],
    
    // Checks an object for illegal characters in fields and values in an object

    checkObjectForIllegalCharacters(obj)::
    
        local fieldNames=[n for n in std.objectFields(obj)];
        local fieldValues=[obj[n] for n in std.objectFields(obj)];
        self.checkForIllegalCharacters(std.join('',fieldNames)+std.join('',fieldValues)),

    // Checks for illegal characters in a string

    checkForIllegalCharacters(s)::
        assert std.isString(s) : 'Can only check for illegal characters in a string';
        std.length(std.filter(function (c) std.setMember(c,'<>\\%&?/:'),std.stringChars(s))) > 0,

    // generates dependsOn Array first by considering any batching required and then by adding explict dependencies

    local generateDependsOn(instance,name,batchSize,instanceCount,serial) = 
       
        assert std.isNumber(batchSize): 'batchSize should be a number';
        assert batchSize <= instanceCount : 'batchSize should not be larger than instanceCount';
        assert batchSize <= maxBatchSize :'batchSize should not be larger than ' + maxBatchSize;
        assert std.isBoolean(serial) : 'serial should be Boolean';

        local implicitDependsOn=if serial then 
            if instance > 1 && instance > batchSize then
                [name+(instance-batchSize+i-(if std.mod(instance,batchSize)==0 then batchSize else std.mod(instance,batchSize))) for i in std.range(1,batchSize)]
            else
                []
        else
            [];

        local explicitDependsOn=getDependsOn(instance,instanceCount);

        local dependsOn=implicitDependsOn+explicitDependsOn;

        assert std.length(dependsOn) <= maxDependsOn : 'Maximum number of dependencies is ' + maxDependsOn;

        if std.length(dependsOn) == 0 then 
            {} 
        else 
            {
                dependsOn:std.uniq(std.sort(dependsOn))
            },

    // Gets explicit depedencies these can either be specified as dependsonAcrossResources where by the list of resources in the array is distributed evenly across each resource instance or as 
    //  dependsOnPerResource where each dependent resource is added to every resource Instance generated

    local getDependsOn(instance,instanceCount)=

        local dependsonAcrossResources=
            if std.objectHas($.properties,'dependsonAcrossResources') then 
                assert std.isArray($.properties.dependsonAcrossResources):'dependsonAcrossResources must be an Array got - '+ std.type($.properties.dependsonAcrossResources);
                
                if std.length($.properties.dependsonAcrossResources) == 0 then 
                    [] 
                else

                    local noOfDependencies=std.length($.properties.dependsonAcrossResources);

                    assert if instanceCount > noOfDependencies then std.mod(instanceCount,noOfDependencies) == 0 else std.mod(noOfDependencies,instanceCount) == 0: 'dependsonAcrossResources must be an Array with equal number of items per instance ';

                    local dependenciesPerResource=std.ceil(noOfDependencies/instanceCount);
                    local offset=(std.mod((instance+noOfDependencies),noOfDependencies)-1);
                
                    std.makeArray(dependenciesPerResource,function (i) $.properties.dependsonAcrossResources[(i*(noOfDependencies/dependenciesPerResource)) + if offset == -1 then noOfDependencies-1 else offset])
            else
                [];

        
        local dependsOnPerResource=
            if std.objectHas($.properties,'dependsOnPerResource') then
                assert std.isArray($.properties.dependsOnPerResource) || std.isString($.properties.dependsOnPerResource) :'dependsOnPerResource must be an Array or string got - '+ std.type($.properties.dependsOnPerResource);
                if std.length($.properties.dependsOnPerResource) == 0 then 
                    []
                else
                    if std.isString($.properties.dependsOnPerResource) then 
                        [$.properties.dependsOnPerResource] else
                    if std.isArray($.properties.dependsOnPerResource) then
                        $.properties.dependsOnPerResource 
                    else
                        []
            else
                [];

        dependsonAcrossResources+dependsOnPerResource,

    // Counts the number of resource tags

    local noOfTags=std.length(std.objectFields($.properties.tags)),

    // Gets and validates the resource tags

    local getTags(tags) = 
        if noOfTags> 0 then
            assert noOfTags <= maxTags : "Maximum number of Tags allowed is " + maxTags;
            assert self.getMaxFieldNameLength($.properties.tags) <= maxTagNameLength : "Maximum Tag Name length is " + maxTagNameLength;
            assert self.getMaxFieldValueLength($.properties.tags) <= maxTagValueLength : "Maximum Tag Value length is " + maxTagValueLength;
            assert !(self.checkObjectForIllegalCharacters($.properties.tags)) :"Illegal Character in Tag Value";
            {   
                tags:
                {
                    [t] : $.properties.tags[t] for t in std.objectFields($.properties.tags) if noOfTags > 0
                }
            }
        else
            {},

    // Gets and validate the serial property on the resource

    local getSerial() = 

        assert std.objectHas($.properties,'serial'): 'serial property is missing';
        assert std.isBoolean( $.properties.serial) || std.isString( $.properties.serial) : 'serial should be Boolean or String';

        if std.isString($.properties.serial) then
            std.asciiLower($.properties.serial) != "false"
        else 
            $.properties.serial,

    // creates ARM Reference function for generated resources

    local generateReferences()=

        if std.objectHas($.properties,'generateReferences') then 
            assert std.isBoolean( $.properties.generateReferences) || std.isString( $.properties.generateReferences) : 'generateReferences should be Boolean or String';
            local generateReference=if std.isString($.properties.generateReferences) then std.asciiLower($.properties.generateReferences) != "false" else $.properties.generateReferences;
            if generateReference then 
                std.makeArray($.properties.instanceCount,function (i) i)
            else 
                []
        else
            [],
    
     // creates ARM ResourceId function for generated resources

    local generateIds()=

        if std.objectHas($.properties,'generateIds') then 
            assert std.isBoolean( $.properties.generateIds) || std.isString( $.properties.generateIds) : 'generateIds should be Boolean or String';
            local generateId=if std.isString($.properties.generateIds) then std.asciiLower($.properties.generateIds) != "false" else $.properties.generateIds;
            if generateId then 
                std.makeArray($.properties.instanceCount,function (i) i)
            else 
                []
        else
            [],

    local isSystemMSI(properties)=
        if std.objectHas(properties,'systemAssignedMSI') then 
            assert std.isBoolean(properties.systemAssignedMSI) || std.isString(properties.systemAssignedMSI) : 'systemAssignedMSI should be Boolean or String';
            local systemMSI=if std.isString(properties.systemAssignedMSI) then std.asciiLower(properties.systemAssignedMSI) != "false" else properties.systemAssignedMSI;
            local hasUserAssignedMSI= std.length(getPerResourceMSIs(properties))+std.length(getAcrossResourceMSIs(properties))>0;
            assert !(systemMSI && hasUserAssignedMSI ): 'Cannot have both System Assigend and User Assigned MSI';
            systemMSI
        else
            false,

    local generateMSIReferences()=

        if $.isMSISupported($.properties) && isSystemMSI($.properties) then 
                std.makeArray($.properties.instanceCount,function (i) i)
        else
            [],

    // get System MSI properties

    local systemMSI()=
        if $.isMSISupported($.properties) && isSystemMSI($.properties) then 
            assert std.isBoolean( $.properties.systemAssignedMSI) || std.isString( $.properties.systemAssignedMSI) : 'systemAssignedMSI should be Boolean or String';
            local systemAssignedMSI=if std.isString($.properties.systemAssignedMSI) then std.asciiLower($.properties.systemAssignedMSI) != "false" else $.properties.systemAssignedMSI;
            if systemAssignedMSI then 
                {
                    "identity": { 
                        "type": "systemAssigned"
                    }
                }
            else 
                {}
         else
            {},

    // Get MSI properties MSI can either be system assigned or there can be up to 32 user Assigned MSI associated with a resource

    local getPerResourceMSIs(properties)=
        if std.objectHas($.properties,'userAssignedMSIIdsPerResource') then   
            assert std.isArray( $.properties.userAssignedMSIIdsPerResource) || std.isString( $.properties.userAssignedMSIIdsPerResource)  : 'userAssignedMSIIdsPerResource should be an array of  or string containing resource names or Ids';
            if std.isArray($.properties.userAssignedMSIIdsPerResource) then
                $.properties.userAssignedMSIIdsPerResource
            else
                [$.properties.userAssignedMSIIdsPerResource],
    
    local getAcrossResourceMSIs(properties)=
        if std.objectHas($.properties,'userAssignedMSIIdsAcrossResources') then   
            assert std.isArray( $.properties.userAssignedMSIIdsAcrossResources) || std.isString( $.properties.userAssignedMSIIdsAcrossResources)  : 'userAssignedMSIIdsAcrossResources should be an array of  or string containing resource names or Ids';     
                if std.isArray($.properties.userAssignedMSIIdsAcrossResources) then
                    $.properties.userAssignedMSIIdsAcrossResources
                else
                    [$.properties.userAssignedMSIIdsAcrossResources],

    local getMSI(instance,instanceCount)=

        // userAssignedMSIIdsPerResource contains one or more MSI resource names or ids to be added to every resource instance
        // userAssignedMSIIdsAcrossResources contains one or more MSI resource names or ids to be distributed across resource instances

        if $.isMSISupported($.properties) then
            if std.objectHas($.properties,'userAssignedMSIIdsPerResource') || std.objectHas($.properties,'userAssignedMSIIdsAcrossResources') then 

                local perresourceMSI=    
                    local msis=getPerResourceMSIs($.properties);
                    if std.length(msis) > 0 then
                        [
                            local msi = msis[n];
                            if isResourceid(msi) then msi else "[resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/','%s')]" % [msi],  
                            for n in std.range(0,std.length(msis)-1)
                        ]
                    else
                        {};

                local acrossresourceMSI=    
                    local msis=getAcrossResourceMSIs($.properties); 
                    if std.length(msis) > 0 then               
                        local noOfMSIsAcrossResources=std.length(msis);
                        assert if instanceCount > noOfMSIsAcrossResources then std.mod(instanceCount,noOfMSIsAcrossResources) == 0 else std.mod(noOfMSIsAcrossResources,instanceCount) == 0: 'userAssignedMSIIdsAcrossResources must be an Array with equal number of items per instance ';
                        local MSIsPerResource=std.ceil(noOfMSIsAcrossResources/instanceCount);
                        local offset=(std.mod((instance+noOfMSIsAcrossResources),noOfMSIsAcrossResources)-1);
                        std.makeArray(MSIsPerResource,
                            function (i) 
                                local msi=msis[(i*(noOfMSIsAcrossResources/MSIsPerResource)) + if offset == -1 then noOfMSIsAcrossResources-1 else offset];
                                if isResourceid(msi) then msi else "[resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/','%s')]" % [msi],)
                    else
                        {};
                
                local allMsis=std.uniq(std.sort(perresourceMSI+acrossresourceMSI));
                local noOfUserAssignedMSIs=std.length(allMsis);
                assert noOfUserAssignedMSIs <= maxMSIInstances: 'Maximum number of user Assinged MSI references is ' + maxMSIInstances;
                if noOfUserAssignedMSIs >0 then
                   {
                        identity+: { 
                            type: "userAssigned",
                            identityIds: allMsis
                        }
                    }
                else 
                    systemMSI()
            else
                systemMSI()
        else
            {},

    local isResourceid(s) =
        local l=std.asciiLower(s);
        if std.startsWith(l,"[resourceid('") && std.endsWith(l,"')]") then
            true
        else
            false,

    // Gets a location if the resource is tracked

    local getLocation(properties) =
        local tracked = $.isTracked(properties);
        if tracked then
            {location: properties.location}
        else
            {},

    // Checks an object for a properties field and returns the value as a new object
   
    local getObjectProperties(obj) =

        if std.objectHas(obj,'properties') && std.length(std.objectFields(obj.properties)) >  0 then
            {properties : obj.properties}
        else
            {},

    isTracked(properties) ::
        if std.objectHasAll(properties,'tracked') then  
            assert std.isBoolean(properties.tracked) || std.isString(properties.tracked) : 'tracked should be Boolean or String';
            if std.isString(properties.tracked) then std.asciiLower(properties.tracked) != "false" else properties.tracked
        else
            true,

    isMSISupported(properties)::
        if std.objectHasAll(properties,'supportsMSI') then  
            assert std.isBoolean(properties.supportsMSI) || std.isString(properties.supportsMSI) : 'supportsMSI should be Boolean or String';
            if std.isString(properties.supportsMSI) then std.asciiLower(properties.supportsMSI) != "false" else properties.supportsMSI
        else
            false,
    
    // This should be overridden by any resource that has a sku

    getSku(p)::{},

    // This should be overridden by any resource that has properties

    getProperties(p,r,c)::{},

    // This should be overridden by any resource that supports zones

    getZones(p,r,c)::{},

    // Validate the instanceCount field

    assert std.isNumber($.properties.instanceCount): 'instanceCount should be a number - got ' + $.properties.instanceCount,
    assert $.properties.instanceCount <= maxInstances : 'instanceCount should less than or equal to ' + maxInstances + ' - got ' + $.properties.instanceCount,

    // Validate the resource name

    assert !($.checkForIllegalCharacters($.properties.name)): 'resource name contains illegal characters ' + $.properties.name,
    assert std.length($.properties.name) - std.length(std.toString($.properties.instanceCount)) <= maxResourceNameLength : 'resource name is too long max length is ' + maxResourceNameLength,

    // Hidden field containing the properties to be used to generate the resource, the parameters hidden property contains the values used to construct this instance

    properties :: {
        name: error "'name' is a required property for resources!",
        type: error "'type' is a required property for resources",
        apiVersion:  error "'apiVersion' is a required property for resources",
        location:  '[resourceGroup().location]',
        tags: {},
        instanceCount: 1,
        serial:false,
        supportsMSI:false,
        systemAssignedMSI:false,
        userAssignedMSIIdsPerResource:[],
        userAssignedMSIIdsAcrossResources:[],
        batchSize:1,
        generateIds:false,
        generateReferences:false,    
        dependsonAcrossResources:[],
        dependsOn:[], 
    } 
    + $.resourceParameters,

    // This property contains the resources that are generated based on the values in properties field, this can be used by callers to get the resources that have been created.

    generatedResources:: [ {
        local resourceName=if $.properties.instanceCount == 1 then $.properties.name else $.properties.name+i,
        name: resourceName,
        type: $.properties.type,
        apiVersion: $.properties.apiVersion,
        id()::"[resourceId('%s', '%s')]" % [ $.properties.type, resourceName ],
        reference()::"[reference(resourceId('%s', '%s'))]" % [ $.properties.type, resourceName ],
        msiId()::"[reference(concat(resourceId('%s', '%s'),'/providers/Microsoft.ManagedIdentity/Identities/default'),'%s').principalId]" % [ $.properties.type, resourceName,msiRPAPIVersion],
    }
    + getTags($.properties.tags)
    + generateDependsOn(i,$.properties.name,$.properties.batchSize,$.properties.instanceCount,getSerial()) 
    + getObjectProperties($.resourceParameters)
    + getMSI(i,$.properties.instanceCount)
    + getLocation($.properties)
    for i in std.range(1,$.properties.instanceCount)],

    // Outputs is exposed as a visible property, it emits a reference and\or a resourceId and\or MSI Id based on the value or presence of the generateReferences and  generateIds properties and if there is a system assigned MSI assocaited with the resource

    // TODO: implement validation of the generated resource e.g. for any references to parameters do the parameters exist.

    getGeneratedResource(i)::
        $.generatedResources[i],
    
    outputs:{}
    + 
    {
        [$.generatedResources[r].name+'-ref']:{
            type:'object',
            value: $.generatedResources[r].reference(),
        },
        for r in generateReferences()
    }
    + 
    {
        [$.generatedResources[r].name+'-id']:{
            type:'string',
            value: $.generatedResources[r].id(),
        },
        for r in generateIds()
    }
    +
    {
        [$.generatedResources[r].name+'-msi']:{
            type: "string",
            value: $.generatedResources[r].msiId(),
        }, 
        for r in generateMSIReferences()
    },
    variables:{},
    parameters:{}, 
}