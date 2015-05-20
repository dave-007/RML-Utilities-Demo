USE tempdb
GO
/*
PURPOSE: Compare trace on Baseline environment versus replay and trace on Comparison environment, 
Looking at unique batches and comparing key metrics.
For use with RML Utilities(https://support.microsoft.com/en-us/kb/944837/) , Performance Analysis databases generated with Readtrace.exe
See Apeendix I of RML Help.pdf (part of RML Utilities) for Performance Analysis database schema
AUTHOR: David Cobb (sql@davidcobb.net)
HISTORY:
2015-05-20 Initial version


*/
-----------------
-- Replace the values in the next two lines with the name of the analysis database 
--for the baseline and comparision PerfAnalysis databases created with ReadTrace
----------------

DECLARE @BaselineAnalysisDB sysname = 'PerfAnalysis_run01_1'
DECLARE @CompareAnalysisDB sysname = 'PerfAnalysis_run01_replay01'


EXEC('CREATE SYNONYM sn_Base_vwBatchUtilization  FOR ' + @BaselineAnalysisDB + '.[ReadTrace].[vwBatchUtilization]')
EXEC('CREATE SYNONYM sn_Base_tblUniqueBatches  FOR ' + @BaselineAnalysisDB + '.[ReadTrace].[tblUniqueBatches]')
EXEC('CREATE SYNONYM sn_Compare_vwBatchUtilization  FOR ' + @CompareAnalysisDB + '.[ReadTrace].[vwBatchUtilization]')
EXEC('CREATE SYNONYM sn_Compare_tblUniqueBatches  FOR ' + @CompareAnalysisDB + '.[ReadTrace].[tblUniqueBatches]')
GO

DECLARE @BatchDisplayCharacters int = 500;

WITH compare1 AS


(
	SELECT TOP 100000
	  LEFT(baseB.NormText,@BatchDisplayCharacters) AS NormalizedBatchText
	--, baseB.SpecialProcID  
	--, compareB.NormText
	, LEN(baseB.NormText) AS BatchCharLength
	--, LEN(compareB.NormText) AS Test_BatchCharLength
	, baseBU.StartingEvents AS Prod_StartingEvents
	, compareBU.StartingEvents AS Test_StartingEvents
	, compareBU.StartingEvents - baseBU.StartingEvents AS StartingEventsDelta
	, baseBU.CompletedEvents AS Prod_CompletedEvents
	, compareBU.CompletedEvents AS Test_CompletedEvents
	, compareBU.CompletedEvents - baseBU.CompletedEvents AS CompletedEventsDelta
	, baseBU.AttentionEvents AS Prod_AttentionEvents
	, compareBU.AttentionEvents AS Test_AttentionEvents
	, compareBU.AttentionEvents - baseBU.AttentionEvents AS AttentionEventsDelta
	, baseBU.AvgDuration/1000000 AS Prod_AvgDuration_Seconds
	, compareBU.AvgDuration/1000000 AS Test_AvgDuration_Seconds
	, (compareBU.AvgDuration - baseBU.AvgDuration) / 1000000 AS AvgDurationDelta_Seconds
	, CASE WHEN baseBU.AvgDuration = 0 THEN 0 ELSE  (compareBU.AvgDuration - baseBU.AvgDuration) / baseBU.AvgDuration * 100  END AS AvgDurationDelta_Percent
	, baseBU.AvgCPU AS Prod_AvgCPU
	, compareBU.AvgCPU AS Test_AvgCPU
	, compareBU.AvgCPU - baseBU.AvgCPU AS AvgCPUDelta
	, baseBU.AvgReads AS Prod_AvgRead
	, compareBU.AvgReads AS Test_AvgRead
	, compareBU.AvgReads - baseBU.AvgReads AS AvgReadDelta
	, baseBU.AvgWrites AS Prod_AvgWrite
	, compareBU.AvgWrites AS Test_AvgWrite
	, compareBU.AvgWrites - baseBU.AvgWrites AS AvgWriteDelta		
	FROM dbo.sn_Base_vwBatchUtilization baseBU
	JOIN dbo.sn_Base_tblUniqueBatches baseB ON baseBU.HashID = baseB.HashID
	JOIN dbo.sn_Compare_tblUniqueBatches compareB ON baseBU.HashID = compareB.HashID
	LEFT JOIN dbo.sn_Compare_vwBatchUtilization compareBU ON baseBU.HashID = compareBU.HashID
	WHERE compareBU.HashID IS NOT NULL
  ), analysis as
  (
  SELECT
	  (SELECT COUNT(*)
		  FROM compare1  
		  WHERE compare1.AvgDurationDelta_Seconds <= 0 
		  ) AS Batches_AWS_FasterOrEqual,
	  (SELECT COUNT(*)
		  FROM compare1  
		  WHERE compare1.AvgDurationDelta_Seconds > 0 
		  ) AS Batches_Prod__Faster	
   )
   SELECT *
   FROM compare1;
   
GO

DROP SYNONYM dbo.sn_Base_vwBatchUtilization
DROP SYNONYM dbo.sn_Base_tblUniqueBatches
DROP SYNONYM dbo.sn_Compare_vwBatchUtilization
DROP SYNONYM dbo.sn_Compare_tblUniqueBatches
