function smoothed_data = slidingsmooth(data,frame, mode)

if ~isvector(data)
    error('''data'' must be a vector')
end

if isscalar(frame)
    frame_length = frame;
    window = ones(frame_length,1);
elseif isvector(frame)
    window = frame;
    frame_length = length(frame);
else
    error('''frame'' must be a vector or a scalar')
end

if nargin<3
    mode = 'median';
end

%% Smooth

% zero pad
x2 = [zeros(ceil((frame_length)/2)-1,1); data(:); zeros(floor(frame_length/2),1)];

% get indexes
index = spdiags(repmat((1:length(x2))',[1 frame_length]),0:-1:-length(x2)+frame_length);

window = repmat(window,[1 length(data)]);

% do calculations
switch lower(mode)
    case 'rms'
        smoothed_data = sqrt(mean((window.*x2(index)).^2));
    case 'median'
        smoothed_data = median((window.*x2(index)));
    case 'mean'
        smoothed_data = mean((window.*x2(index)));
    otherwise
        error('Unknown ''mode'' specified')
end

% transpose if necessary
if size(smoothed_data,1)~=size(smoothed_data,1)
    smoothed_data = smoothed_data';
end

end