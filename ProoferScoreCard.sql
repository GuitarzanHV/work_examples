USE [IS_Metrics]
GO

/****** Object:  View [dbo].[ProoferScorecard]    Script Date: 7/20/2016 3:41:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO







CREATE VIEW [dbo].[ProoferScorecard] AS
SELECT
	mgr.MgrID,
	mgr.MgrFName,
	mgr.MgrLName,

	errors.TotalErrorsYTD,
	errors.TotalErrorsQ1,
	errors.TotalErrorsQ2,
	errors.TotalErrorsQ3,
	errors.TotalErrorsQ4,

	errors.DaysSinceError,

	RANK() OVER(ORDER BY errors.TotalErrorsYTD ASC) AS ErrorRank,

	productivity.FinishedShopsYTD,
	productivity.FinishedShopsMTD,
	productivity.FinishedShopsWTD,
	productivity.FinishedShopsLW,

	total_time.TotalTimeYTD,
	total_time.TotalTimeMTD,
	total_time.TotalTimeWTD,
	total_time.TotalTimeLW,

	productivity.TotalEstTimeYTD,
	productivity.TotalEstTimeMTD,
	productivity.TotalEstTimeWTD,
	productivity.TotalEstTimeLW,

	total_time.TotalTimeYTD - productivity.TotalEstTimeYTD AS VarianceYTD,
	total_time.TotalTimeMTD - productivity.TotalEstTimeMTD AS VarianceMTD,
	total_time.TotalTimeWTD - productivity.TotalEstTimeWTD AS VarianceWTD,
	total_time.TotalTimeLW - productivity.TotalEstTimeLW AS VarianceLW,

	CASE productivity.TotalEstTimeYTD WHEN 0 THEN 0 ELSE total_time.TotalTimeYTD / productivity.TotalEstTimeYTD END AS PercentYTD,
	CASE productivity.TotalEstTimeMTD WHEN 0 THEN 0 ELSE total_time.TotalTimeMTD / productivity.TotalEstTimeMTD END AS PercentMTD,
	CASE productivity.TotalEstTimeWTD WHEN 0 THEN 0 ELSE total_time.TotalTimeWTD / productivity.TotalEstTimeWTD END AS PercentWTD,
	CASE productivity.TotalEstTimeLW WHEN 0 THEN 0 ELSE total_time.TotalTimeLW / productivity.TotalEstTimeLW END AS PercentLW,

	RANK() OVER(ORDER BY CASE productivity.TotalEstTimeYTD WHEN 0 THEN 0 ELSE total_time.TotalTimeYTD / productivity.TotalEstTimeYTD END ASC) AS RankYTD,
	RANK() OVER(ORDER BY CASE productivity.TotalEstTimeMTD WHEN 0 THEN 0 ELSE total_time.TotalTimeMTD / productivity.TotalEstTimeMTD END ASC) AS RankMTD,
	RANK() OVER(ORDER BY CASE productivity.TotalEstTimeWTD WHEN 0 THEN 0 ELSE total_time.TotalTimeWTD / productivity.TotalEstTimeWTD END ASC) AS RankWTD,
	RANK() OVER(ORDER BY CASE productivity.TotalEstTimeLW WHEN 0 THEN 0 ELSE total_time.TotalTimeLW / productivity.TotalEstTimeLW END ASC) AS RankLW,

	NULL AS ErrorCost,
	NULL AS ProductivityCost,
	NULL AS TotalCost,
	NULL AS TotalRank
FROM Managers mgr
LEFT JOIN(SELECT
		shops_proofed.MgrID,

		SUM(CASE WHEN (shops_proofed.JOBSTATUS IN ('finalized', 'client finalized', 'emailed', 'locked') OR shops_proofed.JOBSTATUS = 'hold b' AND shops_proofed.HoldB = 1) 
				AND shops_proofed.OutStamp >= DATEFROMPARTS(YEAR(GETDATE()), 1, 1) 
			THEN 1 ELSE 0 END) AS FinishedShopsYTD,

		SUM(CASE WHEN (shops_proofed.JOBSTATUS IN ('finalized', 'client finalized', 'emailed', 'locked') OR shops_proofed.JOBSTATUS = 'hold b' AND shops_proofed.HoldB = 1) 
				AND shops_proofed.OutStamp BETWEEN DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1) AND EOMONTH(GETDATE()) 
			THEN 1 ELSE 0 END) AS FinishedShopsMTD,

		SUM(CASE WHEN (shops_proofed.JOBSTATUS IN ('finalized', 'client finalized', 'emailed', 'locked') OR shops_proofed.JOBSTATUS = 'hold b' AND shops_proofed.HoldB = 1) 
				AND shops_proofed.OutStamp BETWEEN DATEADD(dd, -(DATEPART(dw, GETDATE())-1), GETDATE()) AND DATEADD(dd, 7-(DATEPART(dw, GETDATE())), GETDATE())
			THEN 1 ELSE 0 END) AS FinishedShopsWTD,

		SUM(CASE WHEN (shops_proofed.JOBSTATUS IN ('finalized', 'client finalized', 'emailed', 'locked') OR shops_proofed.JOBSTATUS = 'hold b' AND shops_proofed.HoldB = 1) 
				AND shops_proofed.OutStamp BETWEEN DATEADD(dd, -(DATEPART(dw, GETDATE())-1)-7, GETDATE()) AND DATEADD(dd, -(DATEPART(dw, GETDATE())), GETDATE()) 
			THEN 1 ELSE 0 END) AS FinishedShopsLW,

		--SUM(DATEDIFF(MI, total_tcrds.InStamp, total_tcrds.OutStamp)) AS TotalTimeYTD,
		--SUM(CASE WHEN total_tcrds.OutStamp BETWEEN DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1) AND EOMONTH(GETDATE()) THEN DATEDIFF(MI, total_tcrds.InStamp, total_tcrds.OutStamp) ELSE 0 END) AS TotalTimeMTD,
		--SUM(CASE WHEN total_tcrds.OutStamp BETWEEN DATEADD(dd, -(DATEPART(dw, GETDATE())-1), GETDATE()) AND DATEADD(dd, 7-(DATEPART(dw, GETDATE())), GETDATE()) THEN DATEDIFF(MI, total_tcrds.InStamp, total_tcrds.OutStamp) ELSE 0 END) AS TotalTimeWTD,
		--SUM(CASE WHEN total_tcrds.OutStamp BETWEEN DATEADD(dd, -(DATEPART(dw, GETDATE())-1)-7, GETDATE()) AND DATEADD(dd, -(DATEPART(dw, GETDATE())), GETDATE()) THEN DATEDIFF(MI, total_tcrds.InStamp, total_tcrds.OutStamp) ELSE 0 END) AS TotalTimeLW,

		SUM(CASE WHEN shops_proofed.OutStamp >= DATEFROMPARTS(YEAR(GETDATE()), 1, 1) THEN shops_proofed.EstimatedAPT ELSE 0 END) AS TotalEstTimeYTD,
		SUM(CASE WHEN shops_proofed.OutStamp BETWEEN DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1) AND EOMONTH(GETDATE()) THEN shops_proofed.EstimatedAPT ELSE 0 END) AS TotalEstTimeMTD,
		SUM(CASE WHEN shops_proofed.OutStamp BETWEEN DATEADD(dd, -(DATEPART(dw, GETDATE())-1), GETDATE()) AND DATEADD(dd, 7-(DATEPART(dw, GETDATE())), GETDATE()) THEN shops_proofed.EstimatedAPT ELSE 0 END) AS TotalEstTimeWTD,
		SUM(CASE WHEN shops_proofed.OutStamp BETWEEN DATEADD(dd, -(DATEPART(dw, GETDATE())-1)-7, GETDATE()) AND DATEADD(dd, -(DATEPART(dw, GETDATE())), GETDATE()) THEN shops_proofed.EstimatedAPT ELSE 0 END) AS TotalEstTimeLW

	FROM(SELECT
			tcrds.JobID,
			mgr.MgrID,
			tcrds.OutStamp,
			export.JOBSTATUS,
			spm.EstimatedAPT,
			spm.StudyTypeRelease AS HoldB
		FROM Managers mgr
		JOIN(SELECT
				a.*
			FROM(SELECT
					tcrds.JobID,
					tcrds.MgrID,
					tcrds.OutStamp,
					ROW_NUMBER() OVER(PARTITION BY tcrds.JobID ORDER BY tcrds.Outstamp DESC) rn
				FROM vw_Reviewer_Timecards tcrds
			) a
			WHERE a.rn = 1
		) tcrds
		ON mgr.MgrID = tcrds.MgrID
		JOIN vw_93dayimport export
		ON tcrds.JobID = export.JOBID
		JOIN ShopsPerMonth spm
		ON export.SURVEYID = spm.SurveyID
		WHERE
			mgr.IsProofer = 1
			AND (export.WAVEID = spm.WaveID OR spm.[StudyTypeRollupID] = 'S')
	) shops_proofed

	GROUP BY
		shops_proofed.MgrID
) productivity
ON mgr.MgrID = productivity.MgrID

LEFT JOIN(SELECT
		MgrID,
		SUM(DATEDIFF(MI, InStamp, OutStamp)) AS TotalTimeYTD,
		SUM(CASE WHEN OutStamp BETWEEN DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1) AND EOMONTH(GETDATE()) THEN DATEDIFF(MI, InStamp, OutStamp) ELSE 0 END) AS TotalTimeMTD,
		SUM(CASE WHEN OutStamp BETWEEN DATEADD(dd, -(DATEPART(dw, GETDATE())-1), GETDATE()) AND DATEADD(dd, 7-(DATEPART(dw, GETDATE())), GETDATE()) THEN DATEDIFF(MI, InStamp, OutStamp) ELSE 0 END) AS TotalTimeWTD,
		SUM(CASE WHEN OutStamp BETWEEN DATEADD(dd, -(DATEPART(dw, GETDATE())-1)-7, GETDATE()) AND DATEADD(dd, -(DATEPART(dw, GETDATE())), GETDATE()) THEN DATEDIFF(MI, InStamp, OutStamp) ELSE 0 END) AS TotalTimeLW
	FROM vw_Reviewer_Timecards
	GROUP BY MgrID
) total_time
ON total_time.MgrID = mgr.MgrID

LEFT JOIN(SELECT
		a.MgrID,
		SUM(CASE WHEN a.jobdate >= DATEFROMPARTS(YEAR(GETDATE()), 1, 1) THEN 1 ELSE 0 END) AS TotalErrorsYTD,
		SUM(CASE WHEN a.jobdate BETWEEN DATEFROMPARTS(YEAR(GETDATE()), 1, 1) AND DATEFROMPARTS(YEAR(GETDATE()), 3, 31) THEN 1 ELSE 0 END) AS TotalErrorsQ1,
		SUM(CASE WHEN a.jobdate BETWEEN DATEFROMPARTS(YEAR(GETDATE()), 4, 1) AND DATEFROMPARTS(YEAR(GETDATE()), 6, 30) THEN 1 ELSE 0 END) AS TotalErrorsQ2,
		SUM(CASE WHEN a.jobdate BETWEEN DATEFROMPARTS(YEAR(GETDATE()), 7, 1) AND DATEFROMPARTS(YEAR(GETDATE()), 9, 30) THEN 1 ELSE 0 END) AS TotalErrorsQ3,
		SUM(CASE WHEN a.jobdate BETWEEN DATEFROMPARTS(YEAR(GETDATE()), 10, 1) AND DATEFROMPARTS(YEAR(GETDATE()), 12, 31) THEN 1 ELSE 0 END) AS TotalErrorsQ4,
		DATEDIFF(dd, MAX(a.jobdate), GETDATE()) AS DaysSinceError
	FROM(SELECT
		USERLOCID AS MgrID,
		jobdate
	FROM vw_93dayimport export
	WHERE SURVEYID = 5731  --SurveyID for the Insite QA survey
	) a
	GROUP BY a.MgrID
) errors
ON mgr.MgrID = errors.MgrID

WHERE
	mgr.IsProofer = 1

GO


