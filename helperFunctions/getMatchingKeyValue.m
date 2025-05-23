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
function [keys, values] = getMatchingKeyValue(map, pattern)
    parameters = regexpi(map.keys, ['\w*' pattern '\w*'], 'match');
    parameters = [parameters{:}];
    values = cell(0, numel(parameters));
    keys = cell(0, numel(parameters));

    for i = 1 : numel(parameters)
        keys{i} = parameters{i};
        values{i} = map(parameters{i});
    end
end

