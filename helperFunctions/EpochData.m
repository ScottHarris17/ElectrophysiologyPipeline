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
classdef EpochData < KeyValueEntity

    properties
        parentCell            % parent cell see @ sa_labs.analysis.entity.CellData
    end

    properties (Transient)
        filtered              % used to filter epochs from GUI
        inMemoryAttributes    % used to visualize derived response but not crucial to store
    end

    properties (Hidden)
        dataLinks             % Map with keys as Amplifier device and values as responses
        responseHandle        % amplifere response call back argumet as stream name
        derivedAttributes     % spikes and other epoch specific pre-processed data
        excluded              % used to delete the epochs
    end

    methods

        function obj = EpochData()
            obj.dataLinks = containers.Map();
            obj.derivedAttributes = containers.Map();
            obj.filtered = true;
            obj.excluded = false;
        end

        function v = get(obj, key)
            v = get@KeyValueEntity(obj, key);

            if isempty(v) && strcmpi(key, 'devices')
                v = obj.getDefaultDeviceType();

                if isempty(v)
                    v = obj.dataLinks.keys;
                end
            elseif isempty(v)
                [~, v] = obj.getMatchingKeyValue(key);
            end
        end

        function [keys, values] = getMatchingKeyValue(obj, pattern)

            % keys - Returns the matched parameter for given
            % search string
            %
            % values - Returns the available parameter values for given
            % search string
            %
            % Pattern matches all the attributes from epoch and  celldata.
            % If found returns the equivalent value
            %
            % usage :
            %       getMatchingKeyValue('chan1')
            %       getMatchingKeyValue('chan1Mode')

            [keys, values] = getMatchingKeyValue@KeyValueEntity(obj, pattern);

            if ~ isempty(obj.parentCell)
                [parentKeys, parentValues] = obj.parentCell.getMatchingKeyValue(pattern);
                keys = [keys, parentKeys];
                values = [values, parentValues];
            end
        end

        function r = getResponse(obj, device)

            % getResponse - finds the device response by executing call back
            % 'responseHandle(path)'
            % path - is obtained from dataLinks by matching it with given
            % device @ see symphony2parser.parse() method for responseHandle
            % definition

            if nargin < 2
                device = obj.getDefaultDeviceType();
            end
            obj.validateDevice(device);

            path = obj.dataLinks(device);
            r = obj.getEpochResponse(path);
        end

        function addDerivedResponse(obj, key, data, device)
            if nargin < 4
                device = obj.getDefaultDeviceType();
            end
            obj.validateDevice(device);

            id = strcat(device, '_', key);
            obj.derivedAttributes(id) = data;
        end

        function addDerivedResponseInMemory(obj, key, data, device)
            if nargin < 4
                device = obj.getDefaultDeviceType();
            end
            obj.validateDevice(device);

            id = strcat(device, '_', key);

            if isempty(obj.inMemoryAttributes)
                obj.inMemoryAttributes = containers.Map();
            end
            obj.inMemoryAttributes(id) = data;
        end

        function r = getDerivedResponse(obj, key, device)

            if nargin < 3
                device = obj.getDefaultDeviceType();
            end
            obj.validateDevice(device);

            r = [];
            id = strcat(device, '_', key);

            if isKey(obj.derivedAttributes, id)
               r = obj.derivedAttributes(id);
               return;
            end

            if ~ isempty(obj.inMemoryAttributes) && isKey(obj.inMemoryAttributes, id)
               r = obj.inMemoryAttributes(id);
            end
        end

        function tf = hasDerivedResponse(obj, key, device)
            id = strcat(device, '_', key);
            tf = isKey(obj.derivedAttributes, id);
        end

        function r = getEpochResponse(obj, path)
            response = obj.responseHandle(obj, path);
            % For symphony v1 data
            if isfield(response, 'unit')
                units = getfield(response, 'unit');
            end
            % For symphony v2 data
            if isfield(response, 'units')
                units = getfield(response, 'units');
            end
            r = struct('quantity', response.quantity, 'units', units);
        end
    end

    methods(Access = protected)

        function header = getHeader(obj)
            try
                type = obj.parentCell.cellType;
                if isempty(type)
                    type = 'unassigned';
                end
                header = ['Displaying epoch information of [ ' type ' ] cell type '];
            catch
                header = getHeader@matlab.mixin.CustomDisplay(obj);
            end
        end
    end

    methods (Access = private)

        function validateDevice(obj, device)

            if ~ isKey(obj.dataLinks, device)
                devices = strjoin(cellstr(obj.dataLinks.keys));
                message = ['device name [ ' device ' ] not found in the h5 response. Available device [' char(devices) ']'];
                error('device:notfound', message);
            end
        end

        function deviceType = getDefaultDeviceType(obj)
            deviceType = [];
            if ~ isempty(obj.parentCell) && ~ obj.parentCell.isClusterRecording()
                deviceType = obj.parentCell.deviceType;
            end
        end
    end
end
