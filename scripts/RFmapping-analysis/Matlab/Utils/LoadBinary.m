function binarySamplesByTimeAndChannel = LoadBinary(filename,zeroBasedChannelNumbersToRead,numberOfInterleavedChannelsInFile,matlabSamplePrecision)
if nargin < 3
    numberOfInterleavedChannelsInFile = 385;
end
if nargin < 4
    matlabSamplePrecision = 'int16';
end

binaryFileName = char(filename);
matlabSamplePrecision = char(matlabSamplePrecision);
oneBasedChannelNumbersToRead = zeroBasedChannelNumbersToRead + 1;

binaryFileInfo = dir(binaryFileName);

bytesPerSingleChannelSample = BinaryBytesPerSample(matlabSamplePrecision);
totalSamplesPerChannelInFile = floor(binaryFileInfo.bytes / ...
    (numberOfInterleavedChannelsInFile * bytesPerSingleChannelSample));

% Map interleaved samples into rows of time and columns of channels.
mappedBinaryFile = memmapfile(binaryFileName,'Format',matlabSamplePrecision);
binarySamplesByTimeAndChannel = zeros(totalSamplesPerChannelInFile, ...
    numel(oneBasedChannelNumbersToRead), matlabSamplePrecision);
for channelListIndex = 1:numel(oneBasedChannelNumbersToRead)
    oneBasedChannelNumber = oneBasedChannelNumbersToRead(channelListIndex);
    linearIndicesForThisChannel = oneBasedChannelNumber: ...
        numberOfInterleavedChannelsInFile: ...
        (totalSamplesPerChannelInFile-1) * numberOfInterleavedChannelsInFile + oneBasedChannelNumber;
    binarySamplesByTimeAndChannel(:,channelListIndex) = mappedBinaryFile.Data(linearIndicesForThisChannel);
end
if isscalar(oneBasedChannelNumbersToRead)
    binarySamplesByTimeAndChannel = binarySamplesByTimeAndChannel(:,1);
end
end

function bytesPerSingleChannelSample = BinaryBytesPerSample(matlabSamplePrecision)
switch char(matlabSamplePrecision)
    case {'int8','uint8','char','uchar','schar'}
        bytesPerSingleChannelSample = 1;
    case {'int16','uint16','short','ushort'}
        bytesPerSingleChannelSample = 2;
    case {'int32','uint32','single','float','int','uint'}
        bytesPerSingleChannelSample = 4;
    case {'int64','uint64','double'}
        bytesPerSingleChannelSample = 8;
end
end
