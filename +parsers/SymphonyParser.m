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
classdef SymphonyParser < handle

    properties
        fname
        info
        cellDataList
    end

    properties (Transient)
        log
    end

    methods

        function obj = SymphonyParser(fname)
            obj.cellDataList = {};
            obj.fname = fname;

            tic;
            obj.info = obj.invokeH5Info();
            elapsedTime = toc;
            [~, name, ~] = fileparts(fname);
            disp(['Elapsed Time for genearting info index for file [ ' name ' ] is [ ' num2str(elapsedTime) ' s ]' ]);
        end

        function map = mapAttributes(obj, h5group, map)
            if nargin < 3
                map = containers.Map();
            end
            try
            if ischar(h5group)
                groupName = h5group;
                h5group = h5info(obj.fname, h5group);
            end
            attributes = h5group.Attributes;
            groupName = h5group.Name;
            
            for i = 1 : length(attributes)
                name = attributes(i).Name;
                root = strfind(name, '/');
                value = attributes(i).Value;

                % convert column vectors to row vectors
                if size(value, 1) > 1
                    value = reshape(value, 1, []);
                end

                if ~ isempty(root)
                    name = attributes(i).Name(root(end) + 1 : end);
                end
                map(name) = value;
            end
            catch e %#ok
                disp(['cannot extract attributes for: [ ' groupName ' ]']);
            end
        end

        function addCellDataByAmps(obj, cellData)
            devices = unique(cellData.getEpochValues('devices'));
            for i= 1:numel(devices)
                device = devices{i};
                if contains(lower(device), 'amp')
                    cell = CellDataByAmp(cellData.recordingLabel, device);
                    obj.cellDataList{end + 1} = cell;
                end
            end
            obj.cellDataList{end + 1} = cellData;
        end

        function hrn = convertDisplayName(~, n)
            hrn = regexprep(n, '([A-Z][a-z]+)', ' $1');
            hrn = regexprep(hrn, '([A-Z][A-Z]+)', ' $1');
            hrn = regexprep(hrn, '([^A-Za-z ]+)', ' $1');
            hrn = strtrim(hrn);

            % TODO: improve underscore handling, this really only works with lowercase underscored variables
            hrn = strrep(hrn, '_', '');

            hrn(1) = upper(hrn(1));
        end

        function r = getResult(obj)
            r = obj.cellDataList;
        end

        function info = invokeH5Info(obj)
            info = h5info(obj.fname);
        end
    end

    methods(Abstract)
        parse(obj)
    end

    methods(Static)

        function version = getVersion(fname)
            version = h5readatt(fname, '/', 'version');
        end
    end
end

