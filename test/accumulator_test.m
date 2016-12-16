% Test Harvey accumulators for filter/smoother

% David Kelley, 2016

classdef accumulator_test < matlab.unittest.TestCase
  
  properties
    bbk
    deai
  end
  
  methods(TestClassSetup)
    function setupOnce(testCase)
      % Factor model data
      baseDir =  [subsref(strsplit(mfilename('fullpath'), 'MFSS'), ...
        struct('type', '{}', 'subs', {{1}})) 'MFSS'];
      addpath(baseDir);
      addpath(fullfile(baseDir, 'examples'));
      
      testCase.bbk = load(fullfile(baseDir, 'examples', 'data', 'bbk_data.mat'));
      testCase.deai = load(fullfile(baseDir, 'examples', 'data', 'deai.mat'));
    end
  end
  
  methods (Test)
    function testNoAccumWithMissing(testCase)
      % Run smoother over a dataset with missing observations, check that
      % its close to a dataset without missing values.
      p = 10; m = 1; timeDim = 500;
      ss = generateARmodel(p, m, false);
      Y = generateData(ss, timeDim);
      
      missingMask = logical(randi([0 1], p, timeDim));
      missingMask(:, sum(missingMask, 1) > 4) = 0;
      obsY = Y;
      obsY(missingMask) = nan;
      
      alpha = ss.smooth(Y);
      obsAlpha = ss.smooth(obsY);
      
      allowedDiffPeriods = sum(sum(missingMask) > 0);
      diffPeriods = sum((abs(alpha(1, :)' - obsAlpha(1,:)')) > 0.02);
      testCase.verifyLessThanOrEqual(diffPeriods, allowedDiffPeriods);
    end
    
    function testSumAccumulatorSmoother(testCase)
      p = 2; m = 1; timeDim = 599;
      ssGen = generateARmodel(p, m, false);
      ssGen.T(1,:) = [0.5 0.3];
      latentY = generateData(ssGen, timeDim);
      
      timeGroups = sort(repmat((1:ceil(timeDim/3))', [3 1]));
      timeGroups(end, :) = [];
      
      aggSeries = logical([0 1]);
      aggY = grpstats(latentY(aggSeries, :)', timeGroups, 'mean')' .* 3;
      aggY(:, end) = [];
      Y = latentY;
      Y(aggSeries, :) = nan;
      Y(aggSeries, 3:3:end) = aggY;
      
      accum = Accumulator(aggSeries, ...
        repmat([1 2 3]', [(timeDim+1)/3, sum(aggSeries)]), ...
        repmat(3, [timeDim+1, sum(aggSeries)]));
      
      ss = StateSpace(ssGen.Z, ssGen.d, ssGen.H, ...
        ssGen.T, ssGen.c, ssGen.R, ssGen.Q);
      ssA = accum.augmentStateSpace(ss);
      
      alpha = ssA.smooth(Y);
      latentAlpha = ssGen.smooth(latentY);
      
      testCase.verifyGreaterThan(corr(alpha(1,:)', latentAlpha(1,:)'), 0.96);
%       testCase.verifyEqual(alpha(1,:), latentAlpha(1,:), 'AbsTol', 0.75, 'RelTol', 0.5);
    end
    
    function testSumAccumutlatorMultiple(testCase)
      p = 3; m = 1; timeDim = 599;
      ssGen = generateARmodel(p, m, false);
      ssGen.T(1,:) = [0.5 0.3];
      latentY = generateData(ssGen, timeDim);
      
      timeGroupsQtr = sort(repmat((1:ceil(timeDim/3))', [3 1]));
      timeGroupsQtr(end, :) = [];
      
      timeGroupsYr= sort(repmat((1:ceil(timeDim/12))', [12 1]));
      timeGroupsYr(end, :) = [];

      aggSeriesQtr = logical([0 1 0]);
      aggY = grpstats(latentY(aggSeriesQtr, :)', timeGroupsQtr, 'mean')' .* 3;
      aggY(:, end) = [];
      Y = latentY;
      Y(aggSeriesQtr, :) = nan;
      Y(aggSeriesQtr, 3:3:end) = aggY;
      
      aggSeriesYr = logical([0 0 1]);
      aggY = grpstats(latentY(aggSeriesYr, :)', timeGroupsYr, 'mean')' .* 12;
      aggY(:, end) = [];
      Y(aggSeriesYr, :) = nan;
      Y(aggSeriesYr, 12:12:end) = aggY;
      
      accum = Accumulator.GenerateRegular(Y', {'', 'sum', 'sum'}, [1 3 12]);
      
      ss = StateSpace(ssGen.Z, ssGen.d, ssGen.H, ...
        ssGen.T, ssGen.c, ssGen.R, ssGen.Q);
      ssA = accum.augmentStateSpace(ss);
      
    end
    
    function testDetroit(testCase)
      import matlab.unittest.constraints.IsFinite;
      detroit = testCase.deai;
      
      ss0 = StateSpace(detroit.Z, detroit.d, detroit.H, ...
        detroit.T, detroit.c, detroit.R, detroit.Q);
      
      deaiAccum = Accumulator(detroit.Harvey.xi, detroit.Harvey.psi, detroit.Harvey.Horizon);
      ss0A = deaiAccum.augmentStateSpace(ss0);
      
      [~, ll] = ss0A.filter(detroit.Y);
      
      testCase.verifyThat(ll, IsFinite);
    end
  end
end