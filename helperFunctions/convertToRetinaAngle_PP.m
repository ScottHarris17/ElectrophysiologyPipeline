function convertedArray = convertToRetinaAngle_PP(angleArray, recordingDate)
% Angles for directional stimuli have to be adjusted because the
% lightcrafter projector can flip the projected image based on the way
% you've set up the display monitors on the rig computer.
% INPUTS:
%     - angleArray: stimulus directins in degrees
%     - recordingDate: datetime of recording
% OUTPUTS:
%     - convertedArray: array of angles that are correct in retinal space


%open the look up file and read it as one long string called info
fID = 'LookUpRetinaAngle_PP.txt';
lookUpFile = fopen(fID, 'r');

info = fscanf(lookUpFile, '%s');
fclose('all');

thisDate = yyyymmdd(recordingDate);

%find everywhere where there's a date listed, along with the corresponding
%conversion. There should be an equal number of dates and conversions.
dateIndexes = strfind(info, 'date:');
conversionIndexes = strfind(info, 'conversion:'); 
if numel(dateIndexes) ~= numel(conversionIndexes); warndlg('Warning, angle conversion lookup file has unequal number of dates and conversions');end

%The dates in the lookup file represent the starting date for that
%conversion type. So, iterate through the file looking at all the dates and
%pick the last date that is before the recording date. This is the one that
%should correspond to the proper conversion type.
for i = 1:numel(dateIndexes)
    date_i = info(dateIndexes(i)+5:dateIndexes(i)+12);
    date_i = str2num(date_i);
    
    if thisDate > date_i && i ~= numel(dateIndexes) 
        continue
    end
    
    %the following only executes on the last iteration (which can also
    %occur the first time that thisDate < date_i
    if i == numel(dateIndexes) && (thisDate > date_i || i == 1) %if it's the last option available take it
            f = i;
    else
        f = i -1; %if it's not the last option, then you'll want to take the one before it
    end
    
    conversion_index = conversionIndexes(f);
    ss = info(conversion_index+11:end);
    cEnd = strfind(ss, '$');
    conversion = ss(1:cEnd-1);
    break
end

%use the conversion type found to run through one of the mapping functions
%below to convert the angles in angleArray.
if strcmp(conversion, 'flipUpDown')
    convertedArray = flipAnglesUpDown(angleArray, 0);
end
end

function convertedArray = flipAnglesUpDown(angleArray, recursions)
%This function flips angles around the X axis. 0 degrees remaps to 0. 90
%degrees remaps to 270. 180 remaps to 180. 270 remaps to 90. 45 remaps to
%315, etc.
convertedArray = zeros(size(angleArray));
recursions = recursions + 1;
for i = 1:numel(angleArray)
    angle = angleArray(i);
    convertedAngle = mod(360-angle, 360);
    
    if convertedAngle > 360 || convertedAngle < 0 || recursions/2 == round(recursions/2)
        %Recursion. The mapping has a cool behavior where you have to 
        %itteratively do the mod function until you get a value between 0
        %and 360, but you also don't want to do it an even number of times
        %because if so you'll end up with the angle you started with and
        %not the one that's reflected over the x axis.
        convertedAngle = flipAnglesUpDown(angle, recursions);
    end
    convertedArray(i) = convertedAngle;
end
return
end



