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
classdef SymphonyV1Parser < parsers.SymphonyParser

    % cell-name.h5
    %   |_ <recorded_by>-<id> (1)
    %     |_epochgroups (1)
    %     |_epochs (2)
    %     |  |_epoch-<id> # epochDataGroups
    %     |       (DS) background
    %     |      |_ protocolParameters (1) epoch attributes
    %     |      |_ responses (2) epoch data links
    %     |         |_ Amplifier_Ch1
    %     |      |_ stimuli
    %     |
    %     |_properties (3) # cell data attributes

    methods

        function obj = SymphonyV1Parser(fname)
            obj = obj@parsers.SymphonyParser(fname);
        end

        function obj = parse(obj)
            data = CellData();

            info = hdf5info(obj.fname);
            info = info.GroupHierarchy(1);
            data.attributes = obj.mapAttributes(info.Groups(1).Groups(3));
            n = length(info.Groups);

            EpochDataGroups = [];
            for i = 1 : n
                EpochDataGroups = [EpochDataGroups info.Groups(i).Groups(2).Groups]; %#ok
            end

            index = 1;
            epochTimes = [];
            for i = 1 : length(EpochDataGroups)

                if length(EpochDataGroups(i).Groups) >= 3 %Complete epoch
                    attributeMap = obj.mapAttributes(EpochDataGroups(i));
                    epochTimes(index) = attributeMap('startTimeDotNetDateTimeOffsetUTCTicks'); %#ok
                    okEpochInd(index) = i; %#ok
                    index = index + 1;
                end
            end

            nEpochs = length(epochTimes);
            if nEpochs < 0
                return
            end

            [epochTimes_sorted, indices] = sort(epochTimes);
            epochTimes_sorted = epochTimes_sorted - epochTimes_sorted(1);
            epochTimes_sorted = double(epochTimes_sorted) / 1E7; % Ticks to second

            data.epochs = EpochData.empty(nEpochs, 0);
            for i = 1 : nEpochs
                groupInd = okEpochInd(indices(i));
                epoch = EpochData();
                epoch.attributes('epochStartTime') = epochTimes_sorted(i);
                epoch.attributes('epochNum') = i;
                epoch.attributes('epochTime') = dotnetTicksToDateTime(epochTimes(groupInd));
                epoch.parentCell = data;
                epoch.attributes = obj.mapAttributes(EpochDataGroups(groupInd).Groups(1), epoch.attributes);
                epoch.dataLinks = obj.addDataLinks(EpochDataGroups(groupInd).Groups(2).Groups);
                epoch.responseHandle = @(e, path) h5read(e.parentCell.get('h5File'), path);
                data.epochs(i) = epoch;
            end
            data.attributes('Nepochs') = nEpochs;
            data.attributes('h5File') = obj.fname;
            data.attributes('parsedDate') = datetime;
            [~, fName, ~] = fileparts(obj.fname);
            data.attributes('label') = fName;
            
            %obj.addCellDataByAmps(data);
            obj.cellDataList{end + 1} = data;
        end

        function map = addDataLinks(~, responseGroups)
            n = length(responseGroups);
            map = containers.Map();

            for i = 1 : n
                h5Name = responseGroups(i).Name;
                delimInd = strfind(h5Name, '/');
                streamName = h5Name(delimInd(end) + 1 : end);
                streamLink = [h5Name, '/data'];
                map(streamName) = streamLink;
            end
        end

        function map = mapAttributes(obj, h5group, map)
            if nargin < 3
                map = containers.Map();
            end
            if ischar(h5group)
                error('cannot accept character as epoch group for symphony 1 parser');
            end
            map = mapAttributes@parsers.SymphonyParser(obj, h5group, map);
            keys = map.keys;
            for i = 1 : numel(keys)
                k = keys{i};
                if isa(map(k), 'hdf5.h5string')
                    v = map(k);
                    map(k) = v.data;
                end
            end
        end
    end

end

