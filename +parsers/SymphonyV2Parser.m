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
classdef SymphonyV2Parser < parsers.SymphonyParser

    % experiement (1)
    %   |__devices (1)
    %   |__epochGroups (2)
    %       |_epochGroup-uuid
    %           |_epochBlocks (1)
    %               |_<protocol_class>-uuid (1) #protocols
    %                   |_epochs (1)
    %                   |   |_epoch-uuid (1)    #h5EpochLinks
    %                   |      |_background (1)
    %                   |      |_protocolParameters (2)
    %                   |      |_responses (3)
    %                   |        |_<device>-uuid (1)
    %                   |            |_data (1)
    %                   |_protocolParameters(2)

    methods

        function obj = SymphonyV2Parser(fname)
            import ch.systemsx.cisd.hdf5.*;
            obj = obj@parsers.SymphonyParser(fname);
        end

        function obj = parse(obj)
            epochsByCellMap = obj.getEpochsByCellLabel(obj.info.Groups(1).Groups(2).Groups);
            sourceLinks = obj.info.Groups(1).Groups(5).Links;
            sourceTree = tree();

            tic;
            for i = 1 : numel(sourceLinks)
                sourceTree = sourceTree.graft(1, obj.buildSourceTree(sourceLinks(i).Value{:}));
            end
            elapsedTime = toc;
            disp(['Generating source tree in [ ' num2str(elapsedTime) ' s ]' ]);

            labels = epochsByCellMap.keys;
            for i = 1 : numel(labels)
                h5epochs =  epochsByCellMap(labels{i});
                cellData = obj.buildCellData(labels{i}, h5epochs);
                cellData.attributes = obj.getSourceAttributes(sourceTree, labels{i}, cellData.attributes);
                %obj.addCellDataByAmps(cellData);
                obj.cellDataList{end + 1} = cellData;
            end
        end

        function eyeIndex = getEyeIndex(~, location)
            if strcmpi(location, 'left')
                eyeIndex = -1;
            elseif strcmpi(location, 'right')
                eyeIndex = 1;
            end
        end

        function cell = buildCellData(obj, label, h5Epochs)
            cell = CellData();

            epochsTime = arrayfun(@(epoch) h5readatt(obj.fname, epoch.Name, 'startTimeDotNetDateTimeOffsetTicks'), h5Epochs);
            [time, indices] = sort(epochsTime);
            sortedEpochTime = double(time - time(1)).* 1e-7;

            lastProtocolId = [];
            epochData = EpochData.empty(numel(h5Epochs), 0);
            disp(['Building cell data for label [' label ']']);
            disp(['Total number of epochs [' num2str(numel(h5Epochs)) ']']);

            for i = 1 : numel(h5Epochs)
                disp(['Processing epoch #' num2str(i)]);
                index = indices(i);
                epochPath = h5Epochs(index).Name;
                [protocolId, name, protocolPath] = obj.getProtocolId(epochPath);

                if ~ strcmp(protocolId, lastProtocolId)
                    % start of new protocol
                    parameterMap = obj.buildAttributes(protocolPath);
                    name = strsplit(name, '.');
                    name = obj.convertDisplayName(name{end});
                    parameterMap('displayName') = name;

                    % add epoch group properties to current prtoocol
                    % parameters
                    group = h5Epochs(index).Name;
                    endOffSet = strfind(group, '/epochBlocks');
                    epochGroupLabel = h5readatt(obj.fname, group(1 : endOffSet), 'label');
                    parameterMap('epochGroupLabel') = epochGroupLabel;
                    parameterMap = obj.buildAttributes([group(1 : endOffSet) 'properties'], parameterMap);

                end
                lastProtocolId = protocolId;
                parameterMap = obj.buildAttributes(h5Epochs(index).Groups(end-2), parameterMap);  % DIRTY FIX AFTER BATHTEMP ADDITION
                parameterMap('epochNum') = i;
                parameterMap('epochStartTime') = sortedEpochTime(i);
                parameterMap('epochTime') = dotnetTicksToDateTime(epochsTime(index));

                e = EpochData();
                e.parentCell = cell;
                e.attributes = containers.Map(parameterMap.keys, parameterMap.values);

                e.dataLinks = obj.getResponses(h5Epochs(index).Groups(end-1).Groups); % DIRTY FIX AFTER BATHTEMP ADDITION
                e.responseHandle = @(e, path) h5read(e.parentCell.get('h5File'), path);
                epochData(i) = e;
            end

            cell.attributes = containers.Map();
            cell.epochs = epochData;
            cell.attributes('Nepochs') = numel(h5Epochs);
            cell.attributes('parsedDate') = datestr(datetime('today'));
            cell.attributes('symphonyVersion') = 2.0; % WHY IS THIS HARDCODED?
            cell.attributes('h5File') = obj.fname;
            %cell.attributes('recordingLabel') =  ['c' char(regexp(label,'[0-9]+', 'match'))]; % LDS: this requires cells to be called "c1...cn"
        end

        function epochGroupMap = getEpochsByCellLabel(obj, epochGroups)
            epochGroupMap = containers.Map();

            for i = 1 : numel(epochGroups)
                h5Epochs = flattenByProtocol(epochGroups(i).Groups(1).Groups);
                label = obj.getSourceLabel(epochGroups(i));
                epochGroupMap = addToMap(epochGroupMap, label, h5Epochs');
            end

            function epochs = flattenByProtocol(protocols)
                epochs = arrayfun(@(p) p.Groups(1).Groups, protocols, 'UniformOutput', false);
                idx = find(~ cellfun(@isempty, epochs));
                epochs = cell2mat(epochs(idx));
            end
        end

        function label = getSourceLabel(obj, epochGroup)

            % check if it is h5 Groups
            % if not present it should be in links
            if numel(epochGroup.Groups) >= 4
                source = epochGroup.Groups(end).Name;
            else
                source = epochGroup.Links(2).Value{:};
            end
            try
                label = h5readatt(obj.fname, source, 'label');
            catch
                source = epochGroup.Links(2).Value{:};
                label = h5readatt(obj.fname, source, 'label');
            end
        end

        function attributeMap = buildAttributes(obj, h5group, map)
            if nargin < 3
                map = containers.Map();
            end
            attributeMap = obj.mapAttributes(h5group, map);
        end

        function sourceTree = buildSourceTree(obj, sourceLink, sourceTree, level)
            % The most time consuming part while parsing the h5 file

            if nargin < 3
                sourceTree = tree();
                level = 0;
            end
            sourceGroup = h5info(obj.fname, sourceLink);

            label = h5readatt(obj.fname, sourceGroup.Name, 'label');
            map = containers.Map();
            map('label') = label;

            sourceProperties = [sourceGroup.Name '/properties'];
            map = obj.mapAttributes(sourceProperties, map);

            sourceTree = sourceTree.addnode(level, map);
            level = level + 1;
            childSource = h5info(obj.fname, [sourceGroup.Name '/sources']);

            for i = 1 : numel(childSource.Groups)
                sourceTree = obj.buildSourceTree(childSource.Groups(i).Name, sourceTree, level);
            end
        end

        function [id, name, path] = getProtocolId(~, epochPath)

            indices = strfind(epochPath, '/');
            id = epochPath(indices(end-2) + 1 : indices(end-1) - 1);
            path = [epochPath(1 : indices(end-1) - 1) '/protocolParameters'] ;
            nameArray = strsplit(id, '-');
            name = nameArray{1};
        end

        function map = getResponses(~, responseGroups)
            map = containers.Map();

            for i = 1 : numel(responseGroups)
                devicePath = responseGroups(i).Name;
                indices = strfind(devicePath, '/');
                id = devicePath(indices(end) + 1 : end);
                deviceArray = strsplit(id, '-');

                name = deviceArray{1};
                path = [devicePath, '/data'];
                map(name) = path;
            end
        end

        function map = getSourceAttributes(~, sourceTree, label, map)
            id = find(sourceTree.treefun(@(node) ~isempty(node) && strcmp(node('label'), label)));

            while id > 0
                currentMap = sourceTree.get(id);
                id = sourceTree.getparent(id);

                if isempty(currentMap)
                    continue;
                end

                keys = currentMap.keys;
                for i = 1 : numel(keys)
                    k = keys{i};
                    map = addToMap(map, k, currentMap(k));
                end
            end
        end

    end
end

