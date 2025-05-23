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
classdef EpochGroup < Group

    properties
        id                  % Identifier of the epochGroup, assigned by FeatureTreeBuilder @see FeatureTreeBuilder.addEpochGroup
        device              % Amplifier channel name Eg 'Amp1'
        epochs              % Epochs composing the group
    end

    properties(SetAccess = immutable)
        splitParameter      % Defines level of epochGroup in tree
        splitValue          % Defines the branch of tree
    end

    properties (Hidden)
        epochIndices            % List of epoch indices to be processed in Offline analysis. @see CellData and FeatureExtractor.extract
        parametersCopied        % Avoid redundant collection of epoch parameters
        cellParametersCopied    % Avoid redundant collection of cell parameters
        functionParameterMap    % Input parameter container for differnt functions which belongs to epochGroup
    end

    methods

        function obj = EpochGroup(splitParameter, splitValue, name)
            if nargin < 3
                name = [splitParameter '==' num2str(splitValue)];
            end
            obj = obj@Group(name);
            obj.splitParameter = splitParameter;
            obj.splitValue = splitValue;
            obj.parametersCopied = false;
            obj.cellParametersCopied = false;
            obj.functionParameterMap = containers.Map();
        end

        function p = getParameter(obj, key)
            p = unique(obj.get(key));
            if numel(p) > 1
                disp('warning: found multiple values');
            end
        end

        function populateEpochResponseAsFeature(obj, epochs)
            % Add epoch response and all additional derived response as features
            if isempty(obj.device)
                    disp('error: device not present');
                return;
            end

            for i = 1:numel(epochs)
                epoch = epochs(i);
                path = epoch.dataLinks(obj.device);
                responseHandle = @() epoch.getEpochResponse(path);
                key = obj.makeValidKey(Constants.EPOCH_KEY_SUFFIX);

                f = obj.createFeature(key, @() transpose(getfield(responseHandle(), 'quantity')), 'append', true);
                f.description.setFromMap(epoch.attributes);
                f.description.set('device', obj.device);

                response = responseHandle();
                if isfield(response, 'units')
                    units = response.('units');
                    f.description.set('units', deblank(units(:,1)'));
                end

                keys = epoch.derivedAttributes.keys;
                for i=1:numel(keys)
                    derivedResponseKey = keys{i};
                    if obj.hasDevice(derivedResponseKey)
                        derivedResponseHandle = @() epoch.derivedAttributes(derivedResponseKey);
                        key = obj.makeValidKey(derivedResponseKey);
                        df = obj.createFeature(key, @() transpose(getfield(derivedResponseHandle(), 'quantity')), 'append', true);
                        derivedResponse = derivedResponseHandle();
                        if isfield(derivedResponse, 'units')
                            units = derivedResponse.('units');
                            df.description.set('units', deblank(units(:,1)'));
                        end                        
                    end
                end
            end
        end

        function data = getFeatureData(obj, key)

            % Given the key, it tries to fetch the exact (or) nearest feature
            % match using regular expression. As a next step, it formats the
            % data on following order
            %
            %   a) In case of array of same size, it concats horizontally
            %   b) In case of array of different size, it creates a cell
            %      array and concats horizontally
            %   c) special case: if the key is the nearest match rather
            %      actual key, then it creates the 1d (or) 2d cell array
            %      depends on the actual data
            %
            %      Example a): Assume 'f1' = 8 x 2, 'f2' = 8 x 2
            %      obj.getFeatureData('f') results in following
            %      [8 x 2] [8 x 2] (i.e 1 × 2 cell array )
            %
            %      Example b) Assume  f1, f2 are 1 × 2 cell array each
            %      'f1' = [3 x 1, 5 x 1] 'f2' = [4 x 1, 2 x 1]
            %      obj.getFeatureData('f') results in following
            %      [3 x 1] [4 x 1]
            %      [5 x 1] [2 x 1]  (i.e  2 × 2 cell array)

            data = getFeatureData@Group(obj, key);
            data = columnMajor(data);

            if isempty(data)
                [~, features] = getMatchingKeyValue(obj.featureMap, key);

                if isempty(features)
                    disp('warning: feature key not found');
                    return
                end

                % data format logic
                data = {};
                
                for i=1:numel(features)
                    featureCell = features{i};
                    d = obj.getData(featureCell);

                    if ~ iscell(d)
                        d = {d};
                    end

                    if size(d, 1) == 1
                       d = d';
                    end
                    data{end + 1} = d; %#ok <AGROW>
                end
                if all(cellfun(@iscell, data))
                    try
                        data =  [data{:}];
                    catch
                        % do nothing
                    end
                end
            end

            function data = columnMajor(data)
                [rows, columns] = size(data);

                if rows == 1 && columns > 1
                    data = data';
                end
            end
        end

        function tf = hasDevice(obj, key)
            tf = any(strfind(upper(key), upper(obj.device)));
        end

        function key = makeValidKey(obj, key)
            key = makeValidKey@Group(obj, key);

            if ~ obj.hasDevice(key)
                key = upper(strcat(obj.device, '_', key));
            end
        end

        function p = getInputParametersForFunction(obj, functionName)
            obj.setInputParametersForFunction(functionName);
            p = obj.functionParameterMap(functionName);
        end

        function setInputParametersForFunction(obj, functionName, parameter)
            if nargin < 3
                try
                    [~, parameter] = helpDocToStructure(functionName);
                catch exception
                    warning(exception.message);
                    parameter = [];
                end
            end
            obj.functionParameterMap(functionName) = parameter;
        end
    end
end

