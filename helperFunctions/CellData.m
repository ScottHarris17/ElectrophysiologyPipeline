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
classdef CellData < KeyValueEntity
    
    properties
        epochs              % Array of epochs belongs to cell. See @sa_labs.analysis.entity.EpochData
    end
    
    properties (Dependent)
        experimentDate      % Experiment date which is grabbed from the first epoch start time
        h5File              % Name of the raw data file
        recordingLabel      % Unique identifier of the cell. <h5File><recordingLabel>_<deviceType> Example: 20170325c1_Amp1 where, h5File: 20170325c, recordingLabel: 1 and deviceType: Amp1
        isClusterRecording  % True if it is the cell cluster, false otherwise
    end
    
    % Below list of attributes will be loaded from the analysis preference files
    % https://schwartz-alalaurila-labs.github.io/sa-labs-analysis-preference/
    
    properties (Dependent)
        cellType            % Cell type of the recorded cell. Cell type can be assigned only when deviceType is empty (i.e non cluster recording)
        recordedBy          % University login name of person who did the experiment. It will be used to synchronize the folder in servers
    end

    properties (Transient)
        deviceType          % It should be empty for cell-cluster
    end
    
    methods
        
        function [values, parameterDescription] = getEpochValues(obj, parameter, epochIndices)
            
            % getEpochValues - By deafult returns attribute values of epochs
            % for given attribute and epochIndices .
            %
            % If the parameter is a function handle, it applies the function
            % to given epoch and returns its value
            %
            % Parameter - epoch attributes or function handle
            % epochIndices - list of epoch indices to be lookedup
            %
            % Usage -
            %      obj.getEpochValues('r_star', [1:100])
            %      obj.getEpochValues(@(epoch) calculateRstar(epoch), [1:100])
            
            if nargin < 3
                epochIndices = 1 : numel(obj.epochs);
            end
            
            [functionHandle, parameterDescription] = getKeyAsFunctionHandle(obj, parameter);
            
            if isempty(functionHandle)
                functionHandle = @(epoch) epoch.get(parameter);
                parameterDescription = parameter;
            end
            
            values = linq(obj.epochs(epochIndices)).where(@(e) ~ e.excluded)...
                        .select(@(e) obj.getValue(functionHandle(e))).toList();

            values = obj.formatCells(values);
        end
        
        function [map, parameterDescription] = getEpochValuesMap(obj, parameter, epochIndices)
            
            % getEpochValuesMap - By deafult returns attribute values as key
            % and matching epochs indices as values
            %
            % @ see also getEpochValues
            %
            % If the parameter is a function handle, it applies the function
            % to given epoch and returns its attribute values and epochs
            % indices
            %
            % Parameter - epoch attributes or function handle
            % epochIndices - list of epoch indices to be lookedup
            %
            % Usage -
            %      obj.getEpochValuesMap('r_star', [1:100])
            %      obj.getEpochValuesMap(@(epoch) calculateRstar(epoch), [1:100])
            
            if nargin < 3
                epochIndices = 1 : numel(obj.epochs);
            end
            
            [functionHandle, parameterDescription] = getKeyAsFunctionHandle(obj, parameter);
            
            if isempty(functionHandle)
                functionHandle = @(epoch) epoch.get(parameter);
                parameterDescription = parameter;
            end
            map = containers.Map();           
            
            for epochIndex = epochIndices
                epoch = obj.epochs(epochIndex);
                
                if ~ epoch.excluded 
                    value = functionHandle(epoch);
                    value = obj.formatCells(value);
                    try
                        map = addToMap(map, num2str(value), epochIndex);
                    catch e %#ok
                        for i = 1: numel(value)
                            v = value{i};
                            map = addToMap(map, num2str(v), epochIndex);
                        end
                    end
                end
            end
            
            keys = map.keys;
            if isempty([keys{:}])
                map = [];
            end
        end
        
        function keySet = getEpochKeysetUnion(obj, epochIndices)
            
            % getEpochKeysetUnion - returns unqiue attributes from epoch
            % array
            
            if nargin < 2
                epochIndices = 1 : numel(obj.epochs);
            end
            keySet = [];
            epochDatas = obj.epochs(epochIndices);
            activeEpochs = epochDatas(~ [epochDatas.excluded]);

            for epoch = activeEpochs
                keySet = epoch.unionAttributeKeys(keySet);
            end
        end
        
        function [params, vals] = getNonMatchingParamValues(obj, excluded, epochIndices)
            
            % getNonMatchingParamValues - returns attributes & values
            % apart from excluded attributes
            %
            % Return parameters
            %    params - cell array of strings
            %    values - cell array of value data type
            
            if nargin < 3
                epochIndices = 1 : numel(obj.epochs);
            end
            
            keys = setdiff(obj.getEpochKeysetUnion(epochIndices), excluded);
            map = containers.Map();
            
            for i = 1:numel(keys)
                key = keys{i};
                values = obj.getEpochValues(key, epochIndices);
                map(key) = obj.formatCells(values);
            end
            params = map.keys;
            vals = map.values;
        end

        function [params, vals] = getUniqueNonMatchingParamValues(obj, excluded, epochIndices)
            
            % getUniqueNonMatchingParamValues - returns unqiue attributes & values
            % apart from excluded attributes
            %
            % Return parameters
            %    params - cell array of strings
            %    values - cell array of value data type
            
            if nargin < 3
                epochIndices = 1 : numel(obj.epochs);
            end
            [params, vals] = obj.getNonMatchingParamValues(excluded, epochIndices);
            for i = 1 : numel(vals)
                value = vals{i};
                if isempty(value) || isscalar(value) || (iscell(value) && ~ iscellstr(value))
                    continue;
                end
                % valid numeric or cell array data type reaches here !
                value = unique(value, 'stable');
                vals{i} = value;
            end
        end

        function [params, vals] = getParamValues(obj, epochIndices)
            
            % getParamValues - returns attributes & values for given epochs
            %
            % see also @getNonMatchingParamValues
            %
            % Return parameters
            %    params - cell array of strings
            %    values - cell array of value data type
            
            if nargin < 2
                epochIndices = 1 : numel(obj.epochs);
            end
            [params, vals] = obj.getNonMatchingParamValues([], epochIndices);
        end
        
        function [params, vals] = getUniqueParamValues(obj, epochIndices)
            
            % getUniqueParamValues - returns unqiue attributes & values
            %
            % see also @getUniqueNonMatchingParamValues
            %
            % Return parameters
            %    params - cell array of strings
            %    values - cell array of value data type
            
            if nargin < 2
                epochIndices = 1 : numel(obj.epochs);
            end
            [params, vals] = obj.getUniqueNonMatchingParamValues([], epochIndices);
        end
                
        function experimentDate = get.experimentDate(obj)
            experimentDate = datestr(obj.epochs(1).get('epochTime'), 'yyyy-mm-dd');
        end
        
        function fname = get.h5File(obj)
            
            fname = obj.get('h5File');
            if ~ isempty(fname)
                [~ , fname] = fileparts(fname);
            end
        end
        
        function label = get.recordingLabel(obj)
            label = strcat(obj.h5File, obj.get('recordingLabel'));
            if ~ obj.isClusterRecording()
                label = strcat(label, '_', obj.deviceType);
            end 
        end
        
        function tf = get.isClusterRecording(obj)
            tf = isempty(obj.deviceType);
        end
            
        function cellType = get.cellType(obj)
            cellType = [];
            if ~ obj.isClusterRecording()
                 key = strcat(obj.deviceType, '_', 'ConfirmedCellType');
                 cellType = obj.get(key);
            end
        end
        
        function set.cellType(obj, cellType)
            % Set cell type only for single cell recording
            
            if obj.isClusterRecording()
                error('cannot assign celType for cell cluster');
            end
            key = strcat(obj.deviceType, '_', 'ConfirmedCellType');
            obj.attributes(key) = cellType;
        end
        
        function recordedBy = get.recordedBy(obj)
            recordedBy = obj.get('recordedBy');
        end
        
        function map = getPropertyMap(obj)
            map = obj.attributes;
        end
    end
    
    methods(Access = protected)
        
        function header = getHeader(obj)
            try
                type = obj.get('cellType');
                if isempty(type)
                    type = 'unassigned';
                end
                header = ['Displaying information about ' type ' cell type '];
            catch
                header = getHeader@matlab.mixin.CustomDisplay(obj);
            end
        end
    end
end