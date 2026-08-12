function trials = RFmapFast_master_polar
% RFMAPFAST_MASTER_POLAR - same 3-function structure as
% RFmapFast_master_ver3 (monitorInformation -> trialStruct_RFmapFast ->
% display function), but drives the polar (azimuth x eccentricity)
% receptive-field mapping stimulus whose geometry was validated in
% test_RFmap_80deg_geometry.m, via ReceptiveFieldMapping_Fast_polar.m.

monitorInformation;

% Azimuth: -120 to +120 deg in 10 deg sectors -> 24 sectors, given as
% bin INNER edges -120:10:110.

% Eccentricity: 0 to 80 deg in 10 deg sectors -> 8 sectors, given as
% bin INNER edges 0:10:70. (10, 70 means 80 deg total. 10, 60 would mean 70
% deg total

% Row order matters: Azimuth, then Eccentricity, then Luminance LAST,
% so Luminance is the fastest-varying parameter. trialStruct_RFmapFast's
% randomization for stimType 'Receptive Field Mapping' relies on that
% ordering to avoid two consecutive trials landing on the same sector.

table = {'Sector Azimuth (deg)', -120, 10, 110;...
         'Sector Eccentricity (deg)', 30, 10, 70;...
         'Sector Luminance (binary)', 0, 1, 1;...
         'Timing (delay,duration,wait)', 0, 0.095, 0;...
         'Blank', 0, [], [];...
         'Randomize', 1, [], [];...
         'Interleave', 0, [], [];...
         'Repeats', 49, [], [];... % TESTING WITH TWO REPEATS, EXPERIMENT WILL HAVE 1 + 49 REPEATS
         'Initialization Screen (s)', 5, [], []};

stimType = 'Receptive Field Mapping';
tag = 'Run01'; %#ok<NASGU>

trials = trialStruct_RFmapFast(stimType, table); % unchanged from Elissa's script
ReceptiveFieldMapping_Fast_polar(trials);

% savename = 'RFmap_Fast_polar_100ms';
% trialStructSave_EB(trials, savename, tag);

end
