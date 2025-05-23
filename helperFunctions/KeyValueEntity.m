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
classdef KeyValueEntity < handle & matlab.mixin.CustomDisplay
    
    properties
        attributes
    end

    properties(SetAccess = protected)
        uuid
    end
    
    methods

        function obj = KeyValueEntity(attributes)
            if nargin < 1
                attributes = containers.Map();
            end
            obj.uuid = char(java.util.UUID.randomUUID);
            obj.attributes = attributes;
        end
        
        function [parameter, description] = getKeyAsFunctionHandle(obj, inputParameter) %#ok
            
            parameter = [];
            description = [];
            
            if isa(inputParameter, 'function_handle')
                description = func2str(inputParameter);
                parameter = inputParameter;
                
            elseif ischar(inputParameter) && strncmp(strtrim(inputParameter), '@', 1)
                description = inputParameter;
                parameter = str2func(inputParameter);
            end
        end
        
        function result = hasAttribute(obj, key)
            keys = obj.attributes.keys;
            if ismember(key, keys)
                result = true;
            else
                result = false;
            end
        end
        
        function v = getValue(obj, value)
            if strcmpi(value, 'null')
                v = [];
            elseif isnumeric(value)
                v = double(value);
            else
                v= value;
            end
            v = obj.formatCells(v);
        end
        
        function values = formatCells(obj, values) %#ok
            
            if ~ iscell(values)
                return;
            end
            
            if all(cellfun(@isempty, values))
                values = {};
                return;
            end
            
            if all(cellfun(@(v) ~ isempty(v) && isnumeric(v), values))
                values = cell2mat(values);
            elseif all(cellfun(@iscellstr, values))
                values = [values{:}];
            end
        end
        
        function value = get(obj, name)
            
            % Returns the matching value for given name from attributes map
            
            value = [];
            if obj.attributes.isKey(name)
                value = obj.attributes(name);
            end
        end
        
        function [keys, values] = getMatchingKeyValue(obj, pattern)
            
            % keys - Returns the matched parameter for given
            % search string
            %
            % values - Returns the available parameter values for given
            % search string
            %
            % usage :
            %       getMatchingKeyValue('chan1')
            %       getMatchingKeyValue('chan1Mode')
            
            [keys, values] = getMatchingKeyValue(obj.attributes, pattern);
        end
        
        function attributeKeys = unionAttributeKeys(obj, attributeKeys)
            
            % unionAttributeKeys - returns the union of { current instance
            % attribute keys } and passed argument {attributeKeys}
            
            if isempty(attributeKeys)
                attributeKeys = obj.attributes.keys;
                return
            end
            attributeKeys = union(attributeKeys, obj.attributes.keys);
        end

        function s = toStructure(obj)
            s = struct();
            map = obj.attributes;
            names = map.keys;

            for i = 1:numel(names)
                name = names{i};
                s.(name) = map(name);
            end
        end

        function t = toTable(obj)
            s = obj.toStructure;

            fields = fieldnames(s);
            for i = numel(fields):-1:1
                values{i} = s.(fields{i});
            end
            values = values';
            
            t = table(fields, values);            
        end
        
    end
    
    methods(Access = protected)
        
        function groups = getPropertyGroups(obj)
            try
                attrKeys = obj.attributes.keys;
                groups = matlab.mixin.util.PropertyGroup.empty(0, 2);
                
                display = struct();
                for i = 1 : numel(attrKeys)
                    
                    values = obj.attributes(attrKeys{i});
                    try
                    values = unique(values);
                    catch 
                        % do nothing if couldnt convert to uniqe
                    end
                    
                    if ~ isempty(values)
                        if numel(values) == 1
                            display.(attrKeys{i}) = values;
                        else
                            display.(attrKeys{i}) = obj.attributes(attrKeys{i});
                        end
                    end
                end
                groups(1) = display;
            catch 
                groups = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
            end
        end
    end
    
end

