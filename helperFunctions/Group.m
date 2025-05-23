%% Clarinet: Electrophysiology time series data analysis
% Copyright (C) 2018 Luca Della Santina
%
%  This file is part of Clarinet
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
% This software is released under the terms of the GPL v3 software license
%
classdef Group < KeyValueEntity

	properties (Access = protected)
        featureMap 	 % Feature map with key as FeatureDescription.type and value as @see Feature instance	
    end

    properties(SetAccess = private)
        name 		% Descriptive name of the Abstract Group
    end
    
    methods 

	    function obj = Group(name)
	        obj.name = name;
	        obj.featureMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
	        obj.uuid = char(java.util.UUID.randomUUID);
            obj.attributes = containers.Map();
	    end

	    function feature = createFeature(obj, id, data, varargin)
	        
	        key = varargin(1 : 2 : end);
	        value = varargin(2 : 2 : end);
	        propertyMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
	        
	        if ~ isempty(key)
	            for i = 1 : numel(key)
	                propertyMap(key{i}) = value{i};
	            end
	        end
	        
	        id = obj.makeValidKey(id);
	        propertyMap('id') = id;
	        description = FeatureDescription(propertyMap);
	        description.id = id;
	        
	        oldFeature = obj.getFeatures(id);
            % The order of if's is important here            
            if isempty(oldFeature)
                feature = Feature(description, data);
                obj.featureMap(id) = feature;
                return
            end
            
	        if  ~ isempty(oldFeature) && isKey(propertyMap, 'append') && propertyMap('append')
                feature = Feature(description, data);
	            obj.appendFeature(feature);
                return
	        end
	        
	        if ~ isempty(oldFeature)
	            oldFeature.data = data;
                oldFeature.description = description;
	            disp(['warning :' id ' for  node ' obj.name]);
	        end
	    end
	    
	    function features = getFeatures(obj, keys)
	        
	        % getFeatures - returns the feature based on FeatureDescription
	        % reference
	        features = [];
	        if ischar(keys)
	            keys = {keys};
	        end
	        
	        keys = unique(keys);
	        for i = 1 : numel(keys)
	            key = keys{i};
	            if isKey(obj.featureMap, key)
	                feature = obj.featureMap(key);
	                features = [features, feature]; %#ok
	            end
	        end
	    end
	    
	    function keySet = getFeatureKey(obj)
	        if numel(obj) > 1
	            result = arrayfun(@(ref) ref.featureMap.keys, obj, 'UniformOutput', false);
	            keySet = unique([result{:}]);
	            return
	        end
	        keySet = obj.featureMap.keys;
	    end

        function data = getFeatureData(obj, key)
            data = [];
            features = [];
            
            if iscellstr(key) && numel(key) > 1
                disp('Multiple feature key present');
            end
            
            if isKey(obj.featureMap, obj.makeValidKey(key))
                features = obj.featureMap(obj.makeValidKey(key));
            end
            
            if ~ isempty(features)
                data = obj.getData(features);
            end
        end

	    function tf = isFeatureEntity(~, refs)
	        tf = all(cellfun(@(ref) isa(ref, 'Feature'), refs));
	    end

	    function k = makeValidKey(~, key)
	    	k = upper(key);
	    end
	end

	methods (Hidden)

	    function appendFeature(obj, newFeatures)        
	        for i = 1 : numel(newFeatures)
	            key = newFeatures(i).description.id;
	            
	            f = obj.getFeatures(key);
	            if ~ isempty(f) && ismember({newFeatures(i).uuid}, {f.uuid})
	                continue;
	            end
	            obj.featureMap = addToMap(obj.featureMap, key, newFeatures(i));
	        end
	    end
	    
	    function setParameters(obj, parameters)
	        
	        % setParameters - Copies from parameters to obj.parameters
	        % @see setParameter
	        
	        if isempty(parameters)
	            return
	        end
	        
	        if isstruct(parameters)
	            names = fieldnames(parameters);
	            for i = 1 : length(names)
	                obj.addParameter(names{i}, parameters.(names{i}));
	            end
	        end
	        
	        if isa(parameters,'containers.Map')
	            names = parameters.keys;
	            for i = 1 : length(names)
	                obj.addParameter(names{i}, parameters(names{i}));
	            end
	        end
	    end
	    
	    function appendParameter(obj, key, value)
	        
	        % append key, value pair to obj.parameters. On empty field it
	        % creates the new field,value else it appends to existing value
	        % if it NOT exist
	        % @see setParameter
	        
	        if isempty(value)
	            return
	        end
	        old = obj.get(key);
	        
	        if isempty(old)
	            obj.addParameter(key, value);
	            return
	        end
	        
	        new = addToCell(old, value);
	        if all(cellfun(@isnumeric, new))
	            new = cell2mat(new);
	        elseif obj.isFeatureEntity(new)
	            new = [new{:}];
	        end
	        obj.addParameter(key, new);
	    end
	    
	    function update(obj, epochGroup, in, out)
	        
	        % Generic code to handle merge from source epochGroup to destination
	        % obj(epochGroup). It merges following,
	        %
	        %   1. properties
	        %   2. Feature
	        %   3. parameters 'matlab structure'
	        %
	        % arguments
	        % epochGroup - source epochGroup
	        % in  - It may be one of source epochGroup property, parameter and feature
	        % out - It may be one of destination obj(epochGroup) property, parameter and feature
	        	        
	        if nargin < 4
	            out = in;
	        end
	        
	        in = char(in);
	        out = char(out);
	        
	        if strcmp(out, 'id')
	            error('id:update:prohibited', 'cannot updated instance id');
	        end
	        
	        % case 1 - epochGroup.in and obj.out is present has properties
	        if isprop(obj, out) && isprop(epochGroup, in)
	            old = obj.(out);
	            obj.(out) = addToCell(old, epochGroup.(in));
	            return
	            
	        end
	        % case 2 - epochGroup.in is struct parameters & obj.out is class property
	        if isprop(obj, out)
	            old = obj.(out);
	            obj.(out) = addToCell(old, epochGroup.get(in));
	            return
	        end
	        
	        % case 3 epochGroup.in is class property but obj.out is struct
	        % parameters
	        if isprop(epochGroup, in)
	            obj.appendParameter(out, epochGroup.(in));
	            return
	        end
	        
	        % case 4 in == out and its a key of featureMap
	        keys = epochGroup.featureMap.keys;
	        if ismember(in, keys)
	            
	            if ~ strcmp(in, out)
	                error('in:out:mismatch', 'In and out should be same for appending feature map')
	            end
	            obj.appendFeature(epochGroup.featureMap(in))
	            return
	        end
	        
	        % case 5 just append the in to out struct parameters
	        % for unknown in parameters, it creates empty out paramters
	        obj.appendParameter(out, epochGroup.get(in));
	    end
	end

	methods(Access = protected)
	    
	    function addParameter(obj, property, value)
	        % setParameters - set property, value pair to parameters
	        obj.attributes(property) = value;
	    end

	    function data = getData(obj, features)
	    	try
	    	    data = [features.data];
            catch
	    	    data = {features.data};
	    	end
	    end

	    function header = getHeader(obj)
	        try
	            header = ['Displaying Epoch group information for [ ' obj.name ' ] for unique values'];
	        catch
	            header = getHeader@matlab.mixin.CustomDisplay(obj);
	        end
	    end    
	end
end