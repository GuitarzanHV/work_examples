USE [IS_Metrics]
GO

/****** Object:  StoredProcedure [dbo].[sp_InsertInsiteJobs]    Script Date: 7/20/2016 3:43:49 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_InsertInsiteJobs]
AS
BEGIN

BEGIN TRANSACTION;

INSERT INTO InsiteJobs WITH (TABLOCKX)
(JobID, SPMID, ClientID, SurveyID, WaveID, ReportDate, JobDate, DueDate, JobStatus,
ShopperFName, ShopperLName, StatusLabel, JobPay, BonusPay, JobExp, SpExp, SchedulerMGrid,
UserLocID, ShopperID, Phone1, Phone2, ShopperState, ShopperZIP, LocZIP, ApprovedShopperFee,
MaxApprovedFee, ApprovedReimbursement, ClientFee)
SELECT
	new_jobs.JOBID,
	new_jobs.SPMID,
	new_jobs.CLIENTID,
	new_jobs.SURVEYID,
	new_jobs.WAVEID,
	new_jobs.REPORTDATE,
	new_jobs.JOBDATE,
	new_jobs.DUEDATE,
	new_jobs.JOBSTATUS,
	new_jobs.SHOPPERFNAME,
	new_jobs.SHOPPERLNAME,
	new_jobs.STATUSLABEL,
	new_jobs.JOBPAY,
	new_jobs.BONUSPAY,
	new_jobs.JOBEXP,
	new_jobs.SPEXP,
	new_jobs.SCHEDULERMGRID,
	new_jobs.USERLOCID,
	new_jobs.SHOPPERID,
	LEFT(new_jobs.PHONE1, 20) AS PHONE1,
	LEFT(new_jobs.PHONE2, 20) AS PHONE2,
	LEFT(new_jobs.SHOPPERSTATE, 30) AS SHOPPERSTATE,
	new_jobs.SHOPPERZIP,
	new_jobs.LOCZIP,
	new_jobs.ApprovedShopperFee,
	new_jobs.MaxApprovedFee,
	new_jobs.Reimbursement AS ApprovedReimbursement,
	new_jobs.Fee AS ClientFee
FROM(SELECT
		jobs.JOBID,
		spm.SPMID,
		jobs.CLIENTID,
		jobs.SURVEYID,
		jobs.WAVEID,
		jobs.REPORTDATE,
		jobs.JOBDATE,
		jobs.DUEDATE,
		jobs.JOBSTATUS,
		jobs.SHOPPERFNAME,
		jobs.SHOPPERLNAME,
		jobs.STATUSLABEL,
		jobs.JOBPAY,
		jobs.BONUSPAY,
		jobs.JOBEXP,
		jobs.SPEXP,
		jobs.SCHEDULERMGRID,
		jobs.USERLOCID,
		jobs.SHOPPERID,
		jobs.PHONE1,
		jobs.PHONE2,
		jobs.SHOPPERSTATE,
		jobs.SHOPPERZIP,
		jobs.LOCZIP,
		spm.ApprovedShopperFee,
		spm.MaxApprovedFee,
		spm.Reimbursement,
		spm.Fee,
		ROW_NUMBER() OVER(PARTITION BY jobs.JOBID ORDER BY spm.SPMID ASC) rn
	FROM tbl93DayExport jobs
	LEFT JOIN ShopsPerMonth spm
	ON
		(jobs.CLIENTID = spm.ClientID
		AND jobs.SURVEYID = spm.SurveyID
		AND (ISNULL(jobs.WAVEID, -1) = ISNULL(spm.WaveID, -1)
			OR EXISTS
				(SELECT a.ClientID, a.SurveyID
				FROM ShopsPerMonth a
				WHERE a.ClientID = jobs.ClientID
					AND a.SurveyID = jobs.SurveyID
				GROUP BY ClientID, SurveyID
				HAVING COUNT(*) = 1
				)
			OR (jobs.ClientID = 731 AND jobs.SurveyID = 5967 AND jobs.WaveID = 1406 AND spm.SPMID = 347) --Triumph Targeted Endorsed
			OR (jobs.ClientID = 731 AND jobs.SurveyID = 5967 AND jobs.WaveID = 1407 AND spm.SPMID = 348) --Triumph Targeted Non-Endorsed
			)
		)
		OR (jobs.ClientID = 711 AND spm.SPMID = 54) --SPMID 54, Chicago Cubs
		OR (jobs.ClientID = 724 AND spm.SPMID = 293) --SPMID 293, PRO Sports Club
) new_jobs
WHERE
	new_jobs.rn = 1
	AND NOT EXISTS (SELECT InsiteJobs.JobID
					FROM InsiteJobs
					WHERE
						InsiteJobs.JobID = new_jobs.JOBID 
						AND InsiteJobs.DueDate > CONVERT(DATE, DATEADD(dd, -94, GETDATE()))
					);

COMMIT TRANSACTION

END
GO


