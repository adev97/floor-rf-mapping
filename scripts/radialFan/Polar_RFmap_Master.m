function trials = Polar_RFmap_Master()
% Polar_RFmap_Master - same 3-function structure as
% Drives the polar (azimuth x eccentricity) receptive-field mapping stimulus whose geometry was validated in
% test_RFmap_80deg_geometry.m, via ReceptiveFieldMapping_Fast_polar.m.

monitorInfo = getMonitorInformation();

% Azimuth: -120 to +120 deg in 10 deg sectors -> 24 sectors, given as
% bin INNER edges -120:10:110.
% Eccentricity: 0 to 80 deg in 10 deg sectors -> 8 sectors, given as
% bin INNER edges 0:10:70. (10, 70 means 80 deg total. 10, 60 would mean 70
% deg total (start at degree : degree increase increments : end at degree)
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
    'Repeats', 2, [], [];... % TESTING WITH TWO REPEATS, EXPERIMENT WILL HAVE 1 + 49 REPEATS
    'Initialization Screen (s)', 5, [], []};

stimType = 'Receptive Field Mapping';
user = 'AD'; % experimenter initials
tag = 'm001'; % change for which mouse it is (m - male, f - female)
iftest = 1; % if this is a test run, 1, if not a test run, 0
trials = trialStruct_RFmapFast(stimType, table); % unchanged from Elissa's script

% Metadata: what code/config/rig/session produced this trials struct, so
% it's saved alongside the data instead of only living in this script.
meta.monitorInfo    = monitorInfo;
meta.user            = user;
meta.tag             = tag;
meta.stimType        = stimType;
meta.stimulusTable   = table;
nowTime              = datetime('now');
meta.dateStr         = char(datetime(nowTime, 'Format', 'yyyyMMdd'));
meta.timestamp       = char(datetime(nowTime, 'Format', 'yyyy-MM-dd HH:mm:ss'));
meta.matlabVersion   = version;

displayPolarSectorRFMap(trials);

savename = 'Polar_RFmap';
trialStructSave(trials, meta, savename, tag, iftest);
end