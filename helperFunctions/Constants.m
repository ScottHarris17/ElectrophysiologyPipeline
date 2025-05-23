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
classdef Constants < handle
    
    properties(Constant)
        
        TEMPLATE_ANALYSIS_NAME = 'analysis'
        TEMPLATE_BUILD_TREE_BY = 'buildTreeBy'
        TEMPLATE_COPY_PARAMETERS = 'copyParameters'
        TEMPLATE_SPLIT_VALUE = 'splitValue'
        TEMPLATE_FEATURE_EXTRACTOR = 'featureExtractor'
        TEMPLATE_TYPE = 'type'
        TEMPLATE_FEATURE_BUILDER_CLASS = 'featureBuilder'
        TEMPLATE_FEATURE_DESC_FILE = 'feature-description-file'
        
        FEATURE_DESC_FILE_NAME = 'feature-description.csv'
        ANALYSIS_LOGGER = 'sa-labs-analysis-core-logger'

        EPOCH_KEY_SUFFIX = 'EPOCH'
    end
end

